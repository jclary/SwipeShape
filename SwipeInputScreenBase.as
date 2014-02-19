/******************************************************************************
SwipeInputScreenBase 
Author - Jai Clary
-------------------------------------------------------------------------------
Usage: 

var swipeScreen:SwipeInputScreenBase = new SwipeInputScreenBase();
addChild(swipeScreen);

//optional
SwipeShape.setSwipeGradient( new Bitmap( new linear_gradient_bitmap_data()) );
-------------------------------------------------------------------------------
This code is free to use, modify, or re-distribute for any purpose with or
without attribution.

This code is provided 'as-is' with no express or implied warranty of any kind.
******************************************************************************/

package{
	
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.events.Event;
	import flash.geom.Point;
	
	public class SwipeInputScreenBase extends MovieClip{

		
		public var mInputShape		:MovieClip;            //catches input
		
		private var mSwipe			:SwipeShape = null;
		
		protected var mMaxNumPoints	:int = 20;				//max number of input points tracked at once
		protected var mPoints		:Vector.<Point> = new Vector.<Point>();//points for swipe drawing
		
		protected var mbIsDragging	:Boolean = false;
		
		public function SwipeInputScreenBase() {
			super();
			addEventListener(Event.ADDED_TO_STAGE, initScreenEvent );
		}

		private function initScreenEvent(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, initScreenEvent );
			initScreen();
		}
		
		//Call once after adding to stage, before using
		public function initScreen():void
		{
			if( !mInputShape )
			{
				mInputShape = new MovieClip();
				addChild( mInputShape );
				resizeInputScreen();
			}
			
			mouseEnabled = false;
			mouseChildren = true;
			activate();
		}
		
		//create a non-visible screen to block and catch input
		public function resizeInputScreen():void
		{
			var targetWidth:int = width > 0 ? width : stage.stageWidth;
			var targetHeight:int = height > 0 ? height : stage.stageHeight;
			//clear old shape
			mInputShape.graphics.clear();
			mInputShape.graphics.beginFill( 0xffffff, 0.01 ); 
			
			//draw new shape to screenSize
			mInputShape.graphics.drawRect( 0,0,targetWidth, targetHeight );
		}
		
		public function activate():void
		{
			mInputShape.addEventListener( MouseEvent.MOUSE_DOWN, touchDownEvent );
			mInputShape.addEventListener( MouseEvent.MOUSE_MOVE, dragEvent );
			mInputShape.addEventListener( MouseEvent.MOUSE_UP, touchReleaseEvent );
			mInputShape.addEventListener( MouseEvent.MOUSE_OUT, touchReleaseEvent );
		}//Activate
		
		public function deactivate():void
		{
			mInputShape.removeEventListener( MouseEvent.MOUSE_DOWN, touchDownEvent );
			mInputShape.removeEventListener( MouseEvent.MOUSE_MOVE, dragEvent );
			mInputShape.removeEventListener( MouseEvent.MOUSE_UP, touchReleaseEvent );
			mInputShape.removeEventListener( MouseEvent.MOUSE_OUT, touchReleaseEvent );
		}
		
		private function touchDownEvent( e:MouseEvent ):void
		{
			var point:Point = mouseToLocal(e);
			touchDown( point.x, point.y );
			mbIsDragging = true;
		}
		
		private function dragEvent( e:MouseEvent ):void
		{
			var point:Point = mouseToLocal(e);
			drag( point.x, point.y );
		}
		
		private function touchReleaseEvent( e:MouseEvent ):void
		{
			var point:Point = mouseToLocal(e);
			touchRelease( point.x, point.y );
			mbIsDragging = false;
		}
		
		protected function touchDown( xLoc:int, yLoc:int ):void
		{
			mPoints = new Vector.<Point>();
			mPoints.push(new Point(xLoc,yLoc));
		}
		
		protected function drag( xLoc:int, yLoc:int, tolerance:Number = 30 ):Boolean
		{
			if( !mbIsDragging )
			{
				return false;
			}
			
			//draw swipe. We call drawSwipe *before* adding the new point,
			//so the swipe will lag ever so slightly behind the user's finger.
			drawSwipe();
			
			var toleranceSq:Number = tolerance*tolerance;
			
			//add point to line if distance is sufficient
			var point:Point = new Point(xLoc,yLoc);
			var prevPoint:Point = mPoints[mPoints.length-1];
			var dist:Point = new Point( point.x-prevPoint.x,point.y-prevPoint.y ); 
			var distSq:Number = dist.x*dist.x + dist.y * dist.y;
			
			
			if( distSq < toleranceSq )
			{
				return false;
			}
			//add point to line
			mPoints.push(point);
			
			if( mPoints.length > mMaxNumPoints )
			  mPoints.shift();
			
			return true;
		}
		
		protected function drawSwipe():void
		{
			var minLength:int = 3;
			if( mPoints.length<minLength )
			{
				return;
			}
			
			if( mSwipe == null )
			{
				var swipe:SwipeShape = new SwipeShape( mPoints );
				swipe.addEventListener( Event.COMPLETE, removeSwipeEvent );
				mInputShape.addChild( swipe );
				mSwipe = swipe;
			}
			else
			{
				mSwipe.updateSwipe( mPoints );
			}
		}//drawSwipe
		
		protected function touchRelease( xLoc:int, yLoc:int ):void
		{
			decaySwipe();
		}
		
		private function decaySwipe():void
		{
			if( mSwipe != null )
			{
				//we've already attached a listener to remove it when it's done
				mSwipe.startDecay();
				mSwipe = null;
			}
		}
		
		private function removeSwipe( swipe:SwipeShape ):void
		{
			if( swipe != null )
			{
				swipe.removeEventListener( Event.COMPLETE, removeSwipeEvent );
				mInputShape.removeChild( swipe );
			}
		}
		
		private function removeSwipeEvent(e:Event ):void
		{
			removeSwipe( e.target as SwipeShape );
		}
		
		private function mouseToLocal(e:MouseEvent):Point
		{
			var point:Point = new Point(e.stageX, e.stageY);
			point = this.globalToLocal(point);
			return point;
		}
		
	}//class
}//package
