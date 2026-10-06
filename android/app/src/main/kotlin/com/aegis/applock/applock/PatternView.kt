package com.aegis.applock.applock

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot

class PatternView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    interface OnPatternListener {
        fun onPatternDetected(pattern: List<Int>)
        fun onPatternCleared()
    }

    var listener: OnPatternListener? = null

    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#4A5568")
        style = Paint.Style.FILL
    }

    private val dotSelectedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#00E5FF")
        style = Paint.Style.FILL
    }

    private val dotRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#3300E5FF")
        style = Paint.Style.STROKE
        strokeWidth = 6f
    }

    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#00E5FF")
        style = Paint.Style.STROKE
        strokeWidth = 10f
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private val selectedDots = mutableListOf<Int>()
    private var currentTouchX = 0f
    private var currentTouchY = 0f
    private var isTouching = false

    private val dotRadius = 14f
    private val hitRadius = 60f

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!isEnabled) return false

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                selectedDots.clear()
                listener?.onPatternCleared()
                isTouching = true
                checkDotHit(event.x, event.y)
                invalidate()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                currentTouchX = event.x
                currentTouchY = event.y
                checkDotHit(event.x, event.y)
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                isTouching = false
                invalidate()
                if (selectedDots.isNotEmpty()) {
                    listener?.onPatternDetected(selectedDots.toList())
                }
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun checkDotHit(x: Float, y: Float) {
        for (i in 0 until 9) {
            val (dotX, dotY) = getDotCenter(i)
            if (hypot((x - dotX).toDouble(), (y - dotY).toDouble()) <= hitRadius) {
                if (!selectedDots.contains(i)) {
                    selectedDots.add(i)
                }
                break
            }
        }
    }

    private fun getDotCenter(index: Int): Pair<Float, Float> {
        val row = index / 3
        val col = index % 3
        val cellWidth = width / 3f
        val cellHeight = height / 3f
        val centerX = col * cellWidth + cellWidth / 2f
        val centerY = row * cellHeight + cellHeight / 2f
        return Pair(centerX, centerY)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // Draw connecting lines
        if (selectedDots.isNotEmpty()) {
            val path = Path()
            val (firstX, firstY) = getDotCenter(selectedDots[0])
            path.moveTo(firstX, firstY)

            for (i in 1 until selectedDots.size) {
                val (nextX, nextY) = getDotCenter(selectedDots[i])
                path.lineTo(nextX, nextY)
            }

            if (isTouching) {
                path.lineTo(currentTouchX, currentTouchY)
            }

            canvas.drawPath(path, linePaint)
        }

        // Draw dots
        for (i in 0 until 9) {
            val (dotX, dotY) = getDotCenter(i)
            val isSelected = selectedDots.contains(i)

            if (isSelected) {
                canvas.drawCircle(dotX, dotY, dotRadius * 2.2f, dotRingPaint)
                canvas.drawCircle(dotX, dotY, dotRadius * 1.3f, dotSelectedPaint)
            } else {
                canvas.drawCircle(dotX, dotY, dotRadius, dotPaint)
            }
        }
    }

    fun clearPattern() {
        selectedDots.clear()
        invalidate()
    }
}
