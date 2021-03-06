/*
 * Copyright (C) 2010 Mamadou Diop.
 *
 * Contact: Mamadou Diop <diopmamadou(at)doubango.org>
 *       
 * This file is part of idoubs Project (http://code.google.com/p/idoubs)
 *
 * idoubs is free software: you can redistribute it and/or modify it under the terms of 
 * the GNU General Public License as published by the Free Software Foundation, either version 3 
 * of the License, or (at your option) any later version.
 *       
 * idoubs is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
 * See the GNU General Public License for more details.
 *       
 * You should have received a copy of the GNU General Public License along 
 * with this program; if not, write to the Free Software Foundation, Inc., 
 * 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 */

#import "DWVideoProducer.h"

#import "tsk_debug.h"

#define DWPRODUCER(self)                ((dw_producer_t*)(self))

#define IPHONE_VIDEO_DEFAULT_WIDTH 400
#define IPHONE_VIDEO_DEFAULT_HEIGHT 304


// Push data (From Video Grabber to our plugin)
int dw_producer_push(dw_producer_t* producer, const void* buffer, tsk_size_t size){
	if(producer && TMEDIA_PRODUCER(producer)->enc_cb.callback){
		return TMEDIA_PRODUCER(producer)->enc_cb.callback(TMEDIA_PRODUCER(producer)->enc_cb.callback_data, buffer, size);
	}
	
	return 0;
}

/* ============ Video Media Producer Interface ================= */
#define dw_producer_set	tsk_null

int dw_producer_prepare(tmedia_producer_t* self, const tmedia_codec_t* codec)
{
	dw_producer_t* producer = (dw_producer_t*)self;
	int ret;
	
	if(!producer || !codec && codec->plugin){
		TSK_DEBUG_ERROR("Invalid parameter");
		return -1;
	}
	
	if(!producer->eProducer){
		TSK_DEBUG_ERROR("Invalid embedded producer");
		return -2;
	}
	
	/* Set Capture parameters */
	producer->negociatedFps = TMEDIA_CODEC_VIDEO(codec)->fps;
	producer->negociatedWidth = TMEDIA_CODEC_VIDEO(codec)->width;
	producer->negociatedHeight = TMEDIA_CODEC_VIDEO(codec)->height;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ret = [producer->eProducer.callback producerPrepared:producer];
	[pool release];
	
	return ret;
}

int dw_producer_start(tmedia_producer_t* self)
{
	dw_producer_t* producer = (dw_producer_t*)self;
	int ret;
	
	if(!producer){
		TSK_DEBUG_ERROR("Invalid parameter");
		return -1;
	}
	
	if(!producer->eProducer){
		TSK_DEBUG_ERROR("Invalid embedded producer");
		return -2;
	}
	
	if(producer->started){
		TSK_DEBUG_WARN("Producer already started");
		return 0;
	}
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ret = [producer->eProducer.callback producerStarted:producer];
	[pool release];
	
	producer->started = (ret == 0);
	return ret;
}

int dw_producer_pause(tmedia_producer_t* self)
{
	dw_producer_t* producer = (dw_producer_t*)self;
	int ret;
	
	if(!producer){
		TSK_DEBUG_ERROR("Invalid parameter");
		return -1;
	}
	
	if(!producer->eProducer){
		TSK_DEBUG_ERROR("Invalid embedded producer");
		return -2;
	}
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ret = [producer->eProducer.callback producerPaused:producer];
	[pool release];
	
	return ret;
}

int dw_producer_stop(tmedia_producer_t* self)
{
	dw_producer_t* producer = (dw_producer_t*)self;
	int ret;
	
	if(!self){
		TSK_DEBUG_ERROR("Invalid parameter");
		return -1;
	}
	
	if(!producer->started){
		TSK_DEBUG_WARN("Producer not started");
		return 0;
	}
	
	if(!producer->eProducer){
		TSK_DEBUG_ERROR("Invalid embedded producer");
		return -2;
	}
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ret = [producer->eProducer.callback producerStopped:producer];
	[pool release];
	
	producer->started = (ret == 0) ?tsk_false:tsk_true;
	return 0;
}


//
//      iOS4 Video producer object definition
//
/* constructor */
static tsk_object_t* dw_producer_ctor(tsk_object_t * self, va_list * app)
{	
	dw_producer_t *producer = (dw_producer_t *)self;
	if(producer){		
		/* init base */
		tmedia_producer_init(TMEDIA_PRODUCER(producer));
		TMEDIA_PRODUCER(producer)->video.chroma = tmedia_nv12;
		TMEDIA_PRODUCER(producer)->video.width = IPHONE_VIDEO_DEFAULT_WIDTH;
		TMEDIA_PRODUCER(producer)->video.height = IPHONE_VIDEO_DEFAULT_HEIGHT;
		/* init self (default values) */
		producer->negociatedFps = 15;
		producer->negociatedWidth = 176;
		producer->negociatedHeight = 144;
		producer->eProducer = [[DWVideoProducer sharedInstance] retain];
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		[producer->eProducer.callback producerCreated:producer];
		[pool release];
	}
	return self;
}
/* destructor */
static tsk_object_t* dw_producer_dtor(tsk_object_t * self)
{ 
	dw_producer_t *producer = (dw_producer_t *)self;
	if(producer){
		
		/* stop */
		if(producer->started){
			dw_producer_stop((tmedia_producer_t*)self);
		}
		
		/* deinit base */
		tmedia_producer_deinit(TMEDIA_PRODUCER(producer));
		/* deinit self */
		[producer->eProducer.callback producerDestroyed:producer];
		[producer->eProducer release];
		
	}
	
	return self;
}
/* object definition */
static const tsk_object_def_t tdshow_producer_def_s = 
{
	sizeof(dw_producer_t),
	dw_producer_ctor, 
	dw_producer_dtor,
	tsk_null, 
};
/* plugin definition*/
static const tmedia_producer_plugin_def_t dw_producer_plugin_def_s = 
{
	&tdshow_producer_def_s,
	
	tmedia_video,
	"iOS4 Video producer",
	
	dw_producer_set,
	dw_producer_prepare,
	dw_producer_start,
	dw_producer_pause,
	dw_producer_stop
};
const tmedia_producer_plugin_def_t *dw_videoProducer_plugin_def_t = &dw_producer_plugin_def_s;



@implementation DWVideoProducer

static DWVideoProducer* instance;

+(DWVideoProducer*)sharedInstance{
	if(!instance){
		instance = [[DWVideoProducer alloc] init];
	}
	return instance;
}

-(NSObject<DWVideoProducerCallback>*) callback{
	return self->callback;
}

-(void) setCallback:(NSObject<DWVideoProducerCallback>*)_callback{
	[self->callback release];
	self->callback = [_callback retain];
}

@end
