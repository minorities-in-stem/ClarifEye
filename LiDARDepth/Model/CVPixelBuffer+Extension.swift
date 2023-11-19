/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An extension to wrap a pixel buffer in a Metal texture object.
*/

import Foundation
import AVFoundation

extension CVPixelBuffer {
    
    func texture(withFormat pixelFormat: MTLPixelFormat, planeIndex: Int, addToCache cache: CVMetalTextureCache) -> MTLTexture? {
        
        var width: Int
        var height: Int
        if (CVPixelBufferIsPlanar(self)) {
            width = CVPixelBufferGetWidthOfPlane(self, planeIndex)
            height = CVPixelBufferGetHeightOfPlane(self, planeIndex)

        } else {
            width = CVPixelBufferGetWidth(self)
            height = CVPixelBufferGetHeight(self)
        }
        
        
        var cvtexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, self, nil, pixelFormat, width, height, planeIndex, &cvtexture)
        guard let texture = cvtexture else { return nil }
        return CVMetalTextureGetTexture(texture)
    }
    
}
