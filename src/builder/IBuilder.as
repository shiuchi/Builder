package builder
{
	public interface IReferenceBuilder
	{
		/** 
		 * 依存関係を構築します
		 */		
		function create():void;
		
		/**
		 * クラスを登録します 
		 * @param clazz クラス
		 * @param instance クラスインスタンスを登録します
		 * @param initializeCall create時にinitializeをcallするかどうか設定します
		 */		
		function register(clazz:Class, instance:* = null, initializeCall:Boolean = true, clean:Boolean = true):void;
	}
}
