package builder
{
	import flash.utils.Dictionary;

	public class Cleaner
	{
		private var dic:Dictionary = new Dictionary(true);
		
		public function Cleaner()
		{
		}
		
		public function add(target:ICleanable):void
		{
			log(getClassName(target));
			if (dic[target] == null) dic[target] = target;
		}
		
		public function remove(target:ICleanable):void
		{
			log(getClassName(target));
			if (dic[target] != null) delete dic[target];
		}
		
		public function clean():void
		{
			var target:ICleanable;
			for  each(target in dic)
			{
				if (target) target.clean();
				delete dic[target];
			}
		}
	}
}