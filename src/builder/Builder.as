package builder
{
	import flash.utils.describeType;
	
	import builder.Cleaner;
	import builder.ICleanable;
	
	/**
	 * Builderはモジュール内でのオブジェクト生成と依存構築を解決するためのクラスです
	 * インスタンスのクラス変数の参照もサポートします
	 * 各モジュールで使用する際はサブクラスを生成し、createメソッドをoverrideし必要なクラスの登録を行なってください
	 * @author shiuchi_sachihiko
	 */	
	public class ReferenceBuilder implements IBuilder
	{
		
		private var map:Object = {};
		private var waiting:Object = {};
		private var inits:Array = [];
		private var cleanables:Vector.<ICleanable> = new Vector.<ICleanable>();
		
		public function ReferenceBuilder()
		{
			if (Object(this).constructor == ReferenceBuilder)throw new Error('Abstruct Class constrauctor error');
		}
		
		public function create():void
		{
			//initialize call
			while (inits.length > 0)
			{
				var instance:Object = inits.shift();
				if (instance.hasOwnProperty("initialize"))
				{
					var func:Function = instance["initialize"] as Function;
					if (func != null && func.length == 0) func.call();
				}
			}
			
			//cleaner
			var cleaner:Cleaner = map["builder::Cleaner"];
			if (cleaner == null) return;
			//cleaner登録
			while (cleanables.length > 0)
			{
				var cleanable:ICleanable = cleanables.shift();
				cleaner.add(cleanable);
			}
		}
		
		/**
		 * 依存関係の構築を行います 
		 * ターゲット自身と取得できるパラメータが対象となります
		 * @param clazz 登録を行うクラス
		 * @param instance インスタンスそのものを登録する場合にそのインスタンス
		 * @param initializeCall //initializeメソッドを呼ぶか否か
		 * @param claen //cleanerが存在する場合、その対象として登録するか否か
		 */		
		public function register(clazz:Class, instance:* = null, initializeCall:Boolean = true, clean:Boolean = true):void
		{
			instance = instance == null ? new clazz() : instance;
			var xml:XML = describeType(instance);
			var name:String = xml.@name;
			//登録してある場合は終了
			if (map[name] != null) return;
			
			log(name);
			//初期化callを希望する場合は登録
			if (initializeCall) inits.push(instance);
			//interface一覧を取得
			var iface:XMLList = xml.implementsInterface;
			//cleanableをinterfaceを実装している場合は登録
			if (clean && checkCleanable(iface)) cleanables.unshift(instance);
			
			registerInterface(instance, iface);
			registerClass(instance, name);
			
			//variableをチェック
			checkAccessor(instance, xml.variable);
			var s:XMLList = xml.variable;
			//アクセサリ一覧をチェック
			checkAccessor(instance, xml.accessor);
		}
		
		/**
		 * インスタンスが保持しているAccessorを登録します
		 * @param instance
		 * 
		 */		
		public function registerAccessor(instance:*):void
		{
			var xml:XML = describeType(instance);
			//variableをチェック
			checkAccessor(instance, xml.variable);
			var s:XMLList = xml.variable;
			//アクセサリ一覧をチェック
			checkAccessor(instance, xml.accessor);
		}
		
		/**
		 * インスタンスが保持しているパラメータを取得します 
		 * @param instance
		 * @param xml
		 */		
		private function checkAccessor(instance:*, list:XMLList):void
		{
			var i:int;
			var len:int = list.length();
			var type:String;
			var param:XML;
			var x:XML;
			var target:*;
			var iface:XMLList;
			for (i = 0; i  < len; i++)
			{
				param = list[i];
				type = param.@type;
				
				//リテラル系は無視
				if (type.indexOf("flash") == 0) continue;
				if (type == "int" || type == "uint" || type == "String" || type == "Number" || type == "Array" || type == "Object" || type == "Boolean" || type.indexOf("Vector") > -1) continue;
				
				//パラメータを吐き出させる
				if (param.@access != "writeonly")
				{
					//取得できるパラメータを登録
					if (map[type] == null && instance[param.@name] != null)
					{
						target = instance[param.@name];
						x = describeType(target);
						//interfaceとして登録
						registerInterface(target, x.implementsInterface);
						//実体クラスとして登録
						registerClass(target, x.@name);
					}
				}
				
				//読み取り専用ならここで終了
				if (param.@access == "readonly") continue;
				
				//次は取得
				if (map[type] != null)
				{
					instance[param.@name] = map[type];
				}
					//出来なければwaitingに登録
				else
				{
					if (waiting[type] == null) waiting[type] = [];
					waiting[type].push(new WaitingData(instance, param.@name, type));
				}
			}
		}
		
		/**
		 * インスタンスをinterfaceとしてmapに登録 
		 * @param instance
		 * @param iface
		 */		
		private function registerInterface(instance:*, iface:XMLList):void
		{
			var i:int;
			var len:int = iface.length();
			var type:String;
			for (i = 0; i < len; i++)
			{
				type = iface[i].@type;
				if (type.indexOf("flash") == 0 ) continue;
				if (type == "builder::ICleanable") continue;
				if (map[type] == null)
				{
					map[type] = instance;
					//interfaceで参照しているものを探す
					checkWaitingList(instance, type);
				}
			}
		}
		
		/**
		 * クラス名でmap登録 
		 * @param instance
		 * @param name
		 * 
		 */		
		private function registerClass(instance:*, name:String):void
		{
			if (map[name] != null) return;
			map[name] = instance;
			checkWaitingList(instance, name);
		}
		
		/**
		 * 依存構築待ちのオブジェクトをチェックします 
		 * @param instance
		 * @param type
		 * @param waiting
		 */		
		private function checkWaitingList(instance:*, type:String):void
		{
			if (waiting[type] != null)
			{
				var arr:Array = waiting[type];
				var i:int;
				var len:int = arr.length;
				var data:WaitingData;
				for (i = 0; i < len; i++)
				{
					data = arr[i];
					data.target[data.name] = instance;
				}
			}
			delete waiting[type];
		}
		
		/**
		 * ICleanableinterfaceを実装しているかどうか判断します 
		 * @param iface
		 * @return 
		 * 
		 */		
		private function checkCleanable(iface:XMLList):Boolean
		{
			var i:int;
			var len:int = iface.length();
			var type:String;
			for (i = 0; i < len; i++)
			{
				type = iface[i].@type;
				if (type == "builder::ICleanable") return true;
			}
			return false;	
		}
	}
}

class WaitingData
{
	public var target:*;
	public var name:String;
	public var type:String;
	
	public function WaitingData(target:*, name:String, type:String)
	{
		this.target = target;
		this.name = name;
		this.type = type;	
	}
}