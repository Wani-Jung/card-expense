package com.wani.card_expense

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Rect
import android.os.Build
import java.io.File
import java.io.FileOutputStream

/**
 * 문자 캡처 OCR 용. 갤럭시 스크롤 캡처처럼 세로로 아주 긴 이미지는 ML Kit 가 줄여서 읽느라 글자를 놓치므로
 * 겹치게 잘라서 넘긴다. 문자 한 건이 잘리는 일이 없도록 겹침을 문자 한 건보다 넉넉하게 둔다.
 * 잘린 조각은 캐시에 잠깐 썼다가 Dart 쪽에서 인식 후 바로 지운다.
 */
object ImageSlicer {
    private const val MAX_SINGLE = 3000 // 이 높이 이하면 자르지 않는다
    private const val SLICE = 2400
    private const val OVERLAP = 900

    fun slice(path: String, cacheDir: File): List<String> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        val w = bounds.outWidth
        val h = bounds.outHeight
        if (w <= 0 || h <= 0) throw IllegalArgumentException("이미지를 읽을 수 없어요")
        // 높이를 너비 기준으로 맞춘다 (가로가 넓은 캡처도 비율이 같도록)
        val slice = maxOf(SLICE, w * 2)
        val overlap = maxOf(OVERLAP, w * 3 / 4)
        if (h <= maxOf(MAX_SINGLE, slice)) return listOf(path)

        val decoder = if (Build.VERSION.SDK_INT >= 31) {
            BitmapRegionDecoder.newInstance(path)
        } else {
            @Suppress("DEPRECATION")
            BitmapRegionDecoder.newInstance(path, false)
        } ?: throw IllegalArgumentException("이미지를 읽을 수 없어요")
        val out = ArrayList<String>()
        try {
            var top = 0
            var i = 0
            while (top < h) {
                val bottom = minOf(top + slice, h)
                val bmp = decoder.decodeRegion(Rect(0, top, w, bottom), null)
                val f = File(cacheDir, "ocr_slice_${System.nanoTime()}_$i.jpg")
                FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.JPEG, 92, it) }
                bmp.recycle()
                out.add(f.absolutePath)
                if (bottom >= h) break
                top = bottom - overlap
                i++
            }
        } finally {
            decoder.recycle()
        }
        return out
    }
}
