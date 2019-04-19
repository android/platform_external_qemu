// Copyright (C) 2019 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#pragma once

#include "android/emulation/GoldfishMediaDefs.h"
#include "android/emulation/H264NaluParser.h"
#include "android/emulation/MediaCodec.h"
#include "android/emulation/MediaH264DecoderPlugin.h"

#include <VideoToolbox/VideoToolbox.h>

#include <cstdint>
#include <string>
#include <vector>

#include <stdio.h>
#include <string.h>

#ifndef kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder
#define kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder CFSTR("RequireHardwareAcceleratedVideoDecoder")
#endif


#include <stddef.h>

namespace android {
namespace emulation {

class MediaH264DecoderVideoToolBox : public MediaH264DecoderPlugin {
public:


    virtual void initH264Context(unsigned int width,
                                 unsigned int height,
                                 unsigned int outWidth,
                                 unsigned int outHeight,
                                 PixelFormat pixFmt) override;
    virtual void reset(unsigned int width,
                                 unsigned int height,
                                 unsigned int outWidth,
                                 unsigned int outHeight,
                                 PixelFormat pixFmt) override;
    virtual void destroyH264Context() override;
    virtual void decodeFrame(void* ptr, const uint8_t* frame, size_t szBytes, uint64_t pts) override;
    virtual void flush(void* ptr) override;
    virtual void getImage(void* ptr) override;

    MediaH264DecoderVideoToolBox();
    virtual ~MediaH264DecoderVideoToolBox();

private:
    void decodeFrameInternal(void* ptr, const uint8_t* frame, size_t szBytes, uint64_t pts, size_t consumedSzBytes);
    // Passes the Sequence Parameter Set (SPS) and Picture Parameter Set (PPS) to the
    // videotoolbox decoder
    CFDataRef createVTDecoderConfig();
    // Callback passed to the VTDecompressionSession
    static void videoToolboxDecompressCallback(void* opaque,
                                               void* sourceFrameRefCon,
                                               OSStatus status,
                                               VTDecodeInfoFlags flags,
                                               CVImageBufferRef image_buffer,
                                               CMTime pts,
                                               CMTime duration);
    static CFDictionaryRef createOutputBufferAttributes(int width,
                                                        int height,
                                                        OSType pix_fmt);
    static CMSampleBufferRef createSampleBuffer(CMFormatDescriptionRef fmtDesc,
                                                void* buffer,
                                                size_t sz);
    static OSType toNativePixelFormat(PixelFormat fmt);

    // We should move these shared memory calls elsewhere, as vpx decoder is also using the same/similar
    // functions
    static void* getReturnAddress(void* ptr);
    static uint8_t* getDst(void* ptr);

    void handleIDRFrame(const uint8_t* ptr, size_t szBytes, uint64_t pts);
    void handleNonIDRFrame(const uint8_t* ptr, size_t szBytes, uint64_t pts);
    void handleSEIFrame(const uint8_t* ptr, size_t szBytes);

    void createCMFormatDescription();
    void recreateDecompressionSession();
    
    // The VideoToolbox decoder session
    VTDecompressionSessionRef mDecoderSession = nullptr;
    // The decoded video buffer
    uint64_t mOutputPts = 0;
    CVImageBufferRef mDecodedFrame = nullptr;
    CMFormatDescriptionRef mCmFmtDesc = nullptr;
    bool mImageReady = false;
    static constexpr int kBPP = 2; // YUV420 is 2 bytes per pixel
    unsigned int mOutputHeight = 0;
    unsigned int mOutputWidth = 0;
    PixelFormat mOutPixFmt; 
    // The calculated size of the outHeader buffer size allocated in the guest.
    // It should be sizeY + (sizeUV * 2), where:
    //  sizeY = outWidth * outHeight,
    //  sizeUV = sizeY / 4
    // It is equivalent to outWidth * outHeight * 3 / 2
    unsigned int mOutBufferSize = 0;
    std::vector<uint8_t> mSPS; // sps NALU
    std::vector<uint8_t> mPPS; // pps NALU

    bool mIsInFlush = false;
}; // MediaH264DecoderVideoToolBox


}  // namespace emulation
}  // namespace android
