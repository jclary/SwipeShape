/*****************************************************************************
SwipeShape 
Author - Jai Clary

-------------------------------------------------------------------------------
Usage: 

//Call once during initialization.  Optional, but recommended
SwipeShape.setSwipeGradient( new Bitmap( new linear_gradient_bitmap_data()) );

//When the swipe begins call:
var swipe:SwipeShape = new SwipeShape( points:Vector.<Points>, config:Object = null );
swipe.addEventListener( Event.COMPLETE, removeSwipeEvent );
screen.addChild(swipe);


//to update the swipe with more points call:
//config is only needed if you're changing the values set by the constructor
swipe.updateSwipe( points, config );

//when the swipe is complete call
swipe.startDecay();

function removeSwipeEvent(e:Event):void
{
	var swipe:SwipeShape = e.target as SwipeShape;
	swipe.removeEventListener( Event.COMPLETE, removeSwipeEvent );
	screen.removeChild(swipe);
}

-------------------------------------------------------------------------------
This code is free to use, modify, or re-distribute for any purpose with or
without attribution.

This code is provided 'as-is' with no express or implied warranty of any kind.
******************************************************************************/
package{
	
	import flash.display.Shape;
	import flash.geom.Point;
	import flash.display.Shader;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.display.Bitmap;
	import flash.display.GradientType;
	import flash.geom.Matrix;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import flashx.textLayout.elements.ParagraphElement;
	
	public class SwipeShape extends MovieClip {


		private var mThicknessMin				:Number = 4;            //minimum thickness of the swipe, not counting the tail
		private var mThicknessMax				:Number = 8;            //max thickness of the swipe, not counting the head
		private var mPointDistanceToleranceSq	:Number = 35*35;        //minimum distance between points - used to cull raw input
		private var mNumSmoothIterations		:int 	= 2;            //number of iterations of smoothing to use
				
		private var mbUseBitmapFill				:Boolean = true;        //whether to use bitmap fill or line color
		private var mFillColor					:uint 	= 0x0099dd;
		
		private var mDecayTimer					:Timer = null;        //Timer for causing the swipe to fade out
		protected var mDecayTime				:int = 20;
		protected var mDecayAmount				:int = 1;
		
		
		private var mPoints						:Vector.<Point> = null;
		
		private static var mSwipeGradient				:Bitmap = null;
		
		public function SwipeShape(input:Vector.<Point> = null, config:Object = null) 
		{
			if( input != null )
			{
				updateSwipe(input, config);
			}
			
			mouseEnabled = false;
			mouseChildren = false;
		}

		public static function setSwipeGradient( bitmap:Bitmap ):void
		{
			mSwipeGradient = bitmap;
		}
		
		public function startDecay():void
		{
			mDecayTimer = new Timer( mDecayTime );
			mDecayTimer.addEventListener( TimerEvent.TIMER, decayEvent );
			mDecayTimer.start();
		}//startDecay
		
		private function decayEvent(e:TimerEvent):void
		{
			var count:int = mDecayAmount;
			var bNeedsRedraw:Boolean = false;
			
			while( mPoints.length > 0 && count > 0)
			{
				bNeedsRedraw = true;
				mPoints.shift();
				count--;
			}//while
			
			if( mPoints.length <3 )
			{
				mDecayTimer.stop();
				mDecayTimer.removeEventListener( TimerEvent.TIMER, decayEvent );
				mDecayTimer = null;
				dispatchEvent( new Event( Event.COMPLETE ) );
			}
			
			else if( bNeedsRedraw )
			{
				updateSwipe();
			}
		}//decayEvent
		
		private function configure( config:Object ):void
		{
			if( config == null )
			{
				return;
			}
			
			if( config.hasOwnProperty( "thicknessMin" ) )
			{
				mThicknessMin = config.thicknessMin;
			}
			if( config.hasOwnProperty( "thicknessMax" ) )
			{
				mThicknessMax = config.thicknessMax;
			}
			if( config.hasOwnProperty( "fillColor" ) )
			{
				mFillColor = config.fillColor;
			}
			if( config.hasOwnProperty( "bUseBitmapFill" ) )
			{
				mbUseBitmapFill = config.bUseBitmapFill;
			}
			if( config.hasOwnProperty( "pointDistanceToleranceSq" ) )
			{
				mPointDistanceToleranceSq = config.pointDistanceToleranceSq;
			}
			if( config.hasOwnProperty( "numSmoothIterations" ) )
			{
				mNumSmoothIterations = config.numSmoothIterations;
			}
		}//configure
		
		public function updateSwipe( input:Vector.<Point> = null, config:Object = null ):void
		{
			
			if( input != null )
				mPoints = input;
			
			configure( config );
			
			var output:Vector.<Point> = new Vector.<Point>();
			
			resolve( mPoints, output );
			var verts:Vector.<Number> = new Vector.<Number>;
			var indices:Vector.<int> = new Vector.<int>;
			
			if( mbUseBitmapFill && mSwipeGradient != null )
			{
				//New way with texture coords and bitmap fill
				var textCoords:Vector.<Number> = new Vector.<Number>;
				createTrianglesBitmap( output, verts, indices, textCoords );
				drawSwipeBitmap( verts, indices, textCoords );
			}
			else
			{
				//old way using a simple color fill
				createTrianglesFill( output, verts, indices );
				drawSwipeFill( verts, indices );
			}
		}//updateSwipe
		
		//===========================================================================
		//BITMAP / GRADIENT FILL
		
		private function drawSwipeBitmap( vertices:Vector.<Number>, indices:Vector.<int>, textCoords:Vector.<Number> ):void
		{
			
			graphics.clear();
			graphics.beginBitmapFill( mSwipeGradient.bitmapData );
			graphics.drawTriangles( vertices, indices, textCoords );
			
			graphics.endFill();
			
		}//drawSwipe
	
		//This version has an 'upper' and 'lower' half of the swipe. 
		//This is so we can use a texture map and bitmap gradient to adjust the color smoothly from center to outside
		private function createTrianglesBitmap( inpoints:Vector.<Point>, 
											   outVerts:Vector.<Number>,  
											   outIndices:Vector.<int>,
											   outTextureCoords:Vector.<Number> ):void
		{
			
			//expand each point into three points, except the first and last.
			var prevPoint:Point = inpoints[0];
			var nextPoint:Point = null;
			
			for( var i:int=1;i<inpoints.length;i++)
			{
				
				nextPoint = inpoints[i];
				var dirp:Point = new Point( nextPoint.x-prevPoint.x, nextPoint.y-prevPoint.y );
				
				if( i==1 )
				{
					outVerts.push( prevPoint.x, prevPoint.y );
					outTextureCoords.push( 0.1,0 );
				}
				else if( i==inpoints.length-1)
				{
					//end point
					//extend the nose a bit for effect
					var noseLength:Number = 25;
					if( dirp.length < noseLength )
					{
						dirp.normalize(noseLength);
						
						outVerts.push( nextPoint.x +dirp.x, nextPoint.y+dirp.y );
					}
					else
					{
						outVerts.push( nextPoint.x, nextPoint.y );
					}
					outTextureCoords.push( 0.1,0 );
				}
				else
				{
					
					//simple linear interpolation from starting thickness to end thickness
					var thickness:Number = lerp( mThicknessMin,mThicknessMax,Number(i)/Number(inpoints.length) );
					//pronounce the tip by enlarging next-to-last point
					if( i== inpoints.length - 2 )
					{
						thickness *= 1.5;
					}
					
					dirp.normalize(thickness);
					var perp:Point = new Point( -dirp.y, dirp.x );
					
					var pointA:Point = new Point( nextPoint.x - perp.x, nextPoint.y - perp.y );
					var pointB:Point = new Point( nextPoint.x + perp.x, nextPoint.y + perp.y );
					
					
					outVerts.push( nextPoint.x, nextPoint.y, pointA.x, pointA.y, pointB.x, pointB.y );
					
					//using 0.9,0.1 instead of 1.0,0 because they gave  ungly anti-alias lines down the center and border
					outTextureCoords.push( 0.9,0,0.1,0,0.1,0 );
				}
				
				prevPoint = nextPoint;
				
				//create triangles
				if( i==1 )
				{
					//first triangle
					outIndices.push( 0, 1, 2, 0, 1, 3 );
					
				}
				else 
				{
					var startIndex:int = 3*(i-2)+1;
					
					outIndices.push( startIndex, startIndex+1, startIndex+3 );
					outIndices.push( startIndex, startIndex+3, startIndex+2 ); 
					
					//if this isn't the last point
					if( i < inpoints.length-1 )
					{
						outIndices.push( startIndex+1, startIndex+4, startIndex+3 );
						outIndices.push( startIndex+2, startIndex+3, startIndex+5 );
					}
				}
			}//for
	    }//createTriangles2
		
		//===========================================================================
		//SIMPLE, MONOCHROMATIC FILL
		
		private function drawSwipeFill( vertices:Vector.<Number>, indices:Vector.<int> ):void
		{
			graphics.clear();
			graphics.beginFill( mFillColor );
			graphics.drawTriangles( vertices, indices );
			graphics.endFill();
		}//drawSwipe
		
		
		private function createTrianglesFill( inpoints:Vector.<Point>, outVerts:Vector.<Number>, outIndices:Vector.<int> ):void
		{
			
			//expand each point into two points, except the first and last.
			var prevPoint:Point = inpoints[0];
			var nextPoint:Point = null;
			
			for( var i:int=1;i<inpoints.length;i++)
			{
				
				nextPoint = inpoints[i];
				var dirp:Point = new Point( nextPoint.x-prevPoint.x, nextPoint.y-prevPoint.y );
				
				if( i==1 )
				{
					outVerts.push( prevPoint.x, prevPoint.y );
				}
				else if( i==inpoints.length-1)
				{
					//end point
					//extend the nose a bit for effect
					var noseLength:Number = 25;
					if( dirp.length < noseLength )
					{
						dirp.normalize(noseLength);
						
						outVerts.push( nextPoint.x +dirp.x, nextPoint.y+dirp.y );
					}
					else
					{
						outVerts.push( nextPoint.x, nextPoint.y );
					}
					
				}
				else
				{
					
					//simple linear interpolation from starting thickness to end thickness
					var thickness:Number = lerp( mThicknessMin,mThicknessMax,Number(i)/Number(inpoints.length) );
					
					//pronounce the tip by enlarging next-to-last point
					if( i== inpoints.length - 2 )
					{
						thickness *= 1.5;
					}
					
					dirp.normalize(thickness);
					var perp:Point = new Point( -dirp.y, dirp.x );
					
					var pointA:Point = new Point( nextPoint.x - perp.x, nextPoint.y - perp.y );
					var pointB:Point = new Point( nextPoint.x + perp.x, nextPoint.y + perp.y );
					
					outVerts.push( pointA.x, pointA.y, pointB.x, pointB.y );
				}
				
				prevPoint = nextPoint;
				
				//create triangles
				if( i==1 )
				{
					//first triangle
					outIndices.push( 0, 1, 2 );
				}
				else 
				{
					var startIndex:int = 2*(i-2)+1;
					outIndices.push( startIndex, startIndex+2, startIndex+1 );
					
					//if this isn't the last point
					if( i < inpoints.length-1 )
					{
						outIndices.push( startIndex+1, startIndex+2, startIndex+3 );
					}
				}
			}//for
	    }//createTriangles
		
		//===========================================================================
		//SMOOTHING FUNCTIONS
		
		
		
		//basically just 'simplify', then 'smooth',
		private function resolve( input:Vector.<Point>, output:Vector.<Point> ):void
		{
			if( input.length < 2 )
			{
				output = output.concat( input );
				return;
			}
			
			var tmp:Vector.<Point> = new Vector.<Point>();
			var simplifyToleranceSq:Number = mPointDistanceToleranceSq;
			
			if( simplifyToleranceSq > 0 && input.length > 3 )
			{
				simplify( input, simplifyToleranceSq, tmp );
				input = tmp;
			}
			
			var smoothIterations:int = mNumSmoothIterations;
			
			if( smoothIterations<=0)
			{
				output = output.concat(input);
			}
			else if( smoothIterations==1 )
			{
				smooth( input, output );
			}
			else
			{
				var numIterations:int = smoothIterations;
				do{
					smooth(input,output);
					tmp = new Vector.<Point>();
					tmp = tmp.concat( output );
					//var old:Array = output;
					input = tmp;
					output= new Vector.<Point>();
				}while(--numIterations > 0)
			}
		}//resolve
		
		private function simplify( points:Vector.<Point>, sqTolerance:Number, out:Vector.<Point> ):void
		{
			var len:int = points.length;
			
			var point:Point = null;
			var prevPoint:Point = points[0];
			
			for( var i:int=1;i<len;i++)
			{
				point = points[i];
				if( distSq( point, prevPoint ) > sqTolerance )
				{
					out.push(point);
					prevPoint = point;
				}
			}//for
			//make sure last point was added
			if( prevPoint != point )
			{
				out.push(point);
			}
		}//simplify
		
		//smooth our series of points
		private function smooth(input:Vector.<Point>, output:Vector.<Point> ):void 
		{
			//first element
			output.push(input[0]);
			//average elements
			for ( var i:int=0; i<input.length-1; i++) 
			{
				var p0:Point = input[i];
				var p1:Point = input[i+1];
		
				var Q:Point = new Point(0.75 * p0.x + 0.25 * p1.x, 0.75 * p0.y + 0.25 * p1.y);
				var R:Point = new Point(0.25 * p0.x + 0.75 * p1.x, 0.25 * p0.y + 0.75 * p1.y);
					output.push(Q);
					output.push(R);
			}//for
			
			//last element
			output.push(input[input.length-1]);
		}//smooth
		
		//===========================================================================
		//HELPER FUNCTIONS
		
		//distance squared. 
		private static function distSq( p1:Point, p2:Point ):Number
		{
			var dx:Number = p1.x - p2.x;
			var dy:Number = p1.y - p2.y;
			
			return dx*dx+dy*dy;
		}//distSq
		
		//simple linear interpolation
		private static function lerp( begin:Number, end:Number, percent:Number ):Number
		{
			if( percent > 1.0 )
			{
				percent = 1.0;
			}
			if( percent < 0 )
			{
				percent = 0;
			}
			return end * percent + (1.0-percent) * begin;
		}//lerp
		
	}//class
	
}//package
