
#import <Foundation/Foundation.h>
#import "CircularBuffer.h"
#import "Novocaine.h"


@interface AudioFileReader : NSObject
{
    float currentTime;
    float duration;
    float samplingRate;
    float latency;
    UInt32 numChannels;
    NSURL *audioFileURL;
    
    InputBlock readerBlock;
    
    BOOL playing;
}

@property (getter=getCurrentTime, setter=setCurrentTime:) float currentTime;
@property (readonly, getter=getDuration) float duration;
@property float samplingRate;
@property UInt32 numChannels;
@property float latency;
@property (nonatomic, copy) NSURL *audioFileURL;
@property (nonatomic, copy) InputBlock readerBlock;
@property BOOL playing;


- (id)initWithAudioFileURL:(NSURL *)urlToAudioFile samplingRate:(float)thisSamplingRate numChannels:(UInt32)thisNumChannels;

// You use this method to grab audio if you have your own callback.
// The buffer'll fill at the speed the audio is normally being played.
- (void)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels;
//- (float)getCurrentTime;
- (void)play;
- (void)pause;
- (void)stop;


@end
