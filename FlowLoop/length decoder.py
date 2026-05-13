import pydicom
import numpy as np
import csv
import os
from scipy.ndimage import gaussian_filter1d
from scipy.signal import find_peaks

# ── SETTINGS ─────────────────────────────────────────────────────────────────
DICOM_PATH       = "DICOM2"
OUTPUT_CSV       = "diameter_results.csv"
DEBUG_FRAMES_DIR = "debug_frames"

CROP_X0, CROP_Y0 = 65,  277   # active ultrasound region (from DICOM header)
CROP_X1, CROP_Y1 = 788, 593


FRAME_TIME_MS = 27.629                # from DICOM FrameTime tag
FPS           = 1000 / FRAME_TIME_MS

SAMPLE_COL          = None  # None = horizontal centre of crop
GRADIENT_SIGMA      = 3.0
GRADIENT_MIN_HEIGHT = 6
GRADIENT_MIN_DIST   = 15
WALL_OFFSET_PX      = 0     # pixels to shift below bright band centre for top wall
MAX_JUMP_PX         = 10    # temporal continuity — max inter-frame wall movement
SAVE_DEBUG_FRAMES   = True
# ─────────────────────────────────────────────────────────────────────────────


def rgb_to_gray(frame_rgb):
    """Convert RGB frame to grayscale using standard luminance weights."""
    return (0.299 * frame_rgb[:, :, 0] +
            0.587 * frame_rgb[:, :, 1] +
            0.114 * frame_rgb[:, :, 2]).astype(np.float32)


def subpixel_peak(signal, peak_idx):
    """Parabolic interpolation for sub-pixel peak position."""
    if 0 < peak_idx < len(signal) - 1:
        y0, y1, y2 = signal[peak_idx - 1], signal[peak_idx], signal[peak_idx + 1]
        denom = y0 - 2 * y1 + y2
        if denom != 0:
            return peak_idx + (y0 - y2) / (2 * denom)
    return float(peak_idx)


def detect_walls(col_gray, wall_offset_px=0):
    """
    Top wall:    subpixel brightest intensity peak in top half, shifted down by wall_offset_px.
    Bottom wall: first positive gradient peak below dynamic midpoint.
    Returns (top_wall, bottom_wall) as sub-pixel floats, or (None, None).
    """
    col_smooth = gaussian_filter1d(col_gray.astype(float), sigma=GRADIENT_SIGMA)
    gradient   = np.gradient(col_smooth)

    # ── BOTTOM WALL — gradient method ────────────────────────────────
    pos_peaks, _ = find_peaks(
         gradient, height=GRADIENT_MIN_HEIGHT, distance=GRADIENT_MIN_DIST)
    neg_peaks, _ = find_peaks(
        -gradient, height=GRADIENT_MIN_HEIGHT, distance=GRADIENT_MIN_DIST)

    if len(pos_peaks) == 0 or len(neg_peaks) == 0:
        return None, None

    dynamic_mid   = (pos_peaks[0] + neg_peaks[-1]) // 2
    pos_after_mid = pos_peaks[pos_peaks > dynamic_mid]

    if len(pos_after_mid) == 0:
        return None, None

    bottom_wall = subpixel_peak(gradient, pos_after_mid[0])

    # ── TOP WALL — subpixel intensity peak method ─────────────────────
    # Search only in top half, above dynamic midpoint
    top_half = col_smooth[:dynamic_mid]

    # Find all local intensity peaks in the top half
    intensity_peaks, intensity_props = find_peaks(
        top_half,
        height=0,                    # accept any peak above zero
        distance=GRADIENT_MIN_DIST,  # reuse same min distance setting
        prominence=5                 # reject very flat bumps — tune if needed
    )

    if len(intensity_peaks) == 0:
        return None, None

    # Select the brightest intensity peak
    brightest_idx = intensity_peaks[np.argmax(intensity_props['peak_heights'])]

    # Subpixel refinement on the intensity signal directly
    bright_centre = subpixel_peak(top_half, brightest_idx)

    # Shift down by offset to place line at inner wall boundary
    top_wall = bright_centre + wall_offset_px

    # Safety check
    if top_wall >= bottom_wall:
        return None, None

    return top_wall, bottom_wall


def save_debug_frame(crop_gray, sample_col, top_wall, bottom_wall,
                     diameter_mm, frame_idx, crop_h, crop_w):
    """Save debug PNG with detected wall positions overlaid."""
    debug = np.stack([crop_gray.astype(np.uint8)] * 3, axis=-1)
    debug[:, sample_col] = [255, 100, 0]  # orange sample column

    if top_wall is not None:
        top_int = max(0, min(int(round(top_wall)),    crop_h - 1))
        bot_int = max(0, min(int(round(bottom_wall)), crop_h - 1))
        debug[top_int, :] = [0, 255, 0]  # green — top wall
        debug[bot_int, :] = [0, 0, 255]  # blue  — bottom wall

    try:
        from PIL import Image, ImageDraw
        img  = Image.fromarray(debug, 'RGB')
        draw = ImageDraw.Draw(img)
        if diameter_mm is not None:
            mid_y = int((top_wall + bottom_wall) / 2)
            draw.text((sample_col + 5, mid_y), f"{diameter_mm:.3f}mm",
                      fill=(255, 255, 255))
        img.save(f"{DEBUG_FRAMES_DIR}/frame_{frame_idx:04d}.png")
    except ImportError:
        with open(f"{DEBUG_FRAMES_DIR}/frame_{frame_idx:04d}.ppm", 'wb') as f:
            f.write(f"P6\n{crop_w} {crop_h}\n255\n".encode())
            f.write(debug.tobytes())


def process_dicom(dicom_path, output_csv):
    print(f"Reading DICOM: {dicom_path}")
    ds         = pydicom.dcmread(dicom_path)
    frames_raw = ds.pixel_array
    num_frames = frames_raw.shape[0]

    CM_PER_PIXEL  = float(ds.PhysicalDeltaX)  # from DICOM PhysicalDeltaX/Y
    MM_PER_PIXEL  = CM_PER_PIXEL * 10

    crop_h     = CROP_Y1 - CROP_Y0
    crop_w     = CROP_X1 - CROP_X0
    sample_col = SAMPLE_COL if SAMPLE_COL is not None else crop_w // 2

    print(f"Frames: {num_frames}  |  FPS: {FPS:.1f}  |  mm/px: {MM_PER_PIXEL:.5f}")
    print(f"Crop: y={CROP_Y0}:{CROP_Y1}, x={CROP_X0}:{CROP_X1}  ({crop_w}x{crop_h}px)")
    print(f"Sample column: {sample_col}\n")

    if SAVE_DEBUG_FRAMES:
        os.makedirs(DEBUG_FRAMES_DIR, exist_ok=True)

    results          = []
    failed_frames    = 0
    corrected_frames = 0
    prev_top         = None
    prev_bottom      = None

    for i in range(num_frames):
        gray = rgb_to_gray(frames_raw[i])
        crop = gray[CROP_Y0:CROP_Y1, CROP_X0:CROP_X1]
        col  = crop[:, sample_col]

        top_wall, bottom_wall = detect_walls(col, wall_offset_px=WALL_OFFSET_PX)

        # Temporal continuity — revert to previous frame if jump too large
        if top_wall is not None and prev_top is not None:
            top_jump    = abs(top_wall    - prev_top)
            bottom_jump = abs(bottom_wall - prev_bottom)
            if top_jump > MAX_JUMP_PX or bottom_jump > MAX_JUMP_PX:
                top_wall, bottom_wall = prev_top, prev_bottom
                corrected_frames += 1
                print(f"  Frame {i:04d}: jump corrected "
                      f"(top={top_jump:.1f}px, bot={bottom_jump:.1f}px)")

        if top_wall is not None:
            prev_top, prev_bottom = top_wall, bottom_wall

        if top_wall is not None:
            diameter_px = bottom_wall - top_wall
            diameter_mm = round(diameter_px * MM_PER_PIXEL, 4)
            diameter_cm = round(diameter_px * CM_PER_PIXEL, 5)
        else:
            diameter_px = diameter_mm = diameter_cm = None
            failed_frames += 1

        results.append({
            "frame":          i,
            "time_ms":        round(i * FRAME_TIME_MS, 2),
            "top_wall_px":    round(top_wall,     4) if top_wall    is not None else None,
            "bottom_wall_px": round(bottom_wall,  4) if bottom_wall is not None else None,
            "diameter_px":    round(diameter_px,  4) if diameter_px is not None else None,
            "diameter_mm":    diameter_mm,
            "diameter_cm":    diameter_cm,
        })

        if SAVE_DEBUG_FRAMES:
            save_debug_frame(crop, sample_col, top_wall, bottom_wall,
                             diameter_mm, i, crop_h, crop_w)

        if i % 50 == 0:
            print(f"  Processed {i}/{num_frames} frames...")

    with open(output_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "frame", "time_ms", "top_wall_px", "bottom_wall_px",
            "diameter_px", "diameter_mm", "diameter_cm"
        ])
        writer.writeheader()
        writer.writerows(results)

    diameters_mm = [r["diameter_mm"] for r in results if r["diameter_mm"] is not None]
    if diameters_mm:
        print(f"\nDone! Processed {num_frames} frames.")
        print(f"  Successful:  {len(diameters_mm)}/{num_frames}")
        print(f"  Failed:      {failed_frames}/{num_frames}")
        print(f"  Corrected:   {corrected_frames}/{num_frames}")
        print(f"  Diameter — min: {min(diameters_mm):.3f}mm  "
              f"max: {max(diameters_mm):.3f}mm  "
              f"mean: {np.mean(diameters_mm):.3f}mm")
        print(f"\nResults saved to: {output_csv}")
        if SAVE_DEBUG_FRAMES:
            print(f"Debug frames:     {DEBUG_FRAMES_DIR}/")
    else:
        print("\nWARNING: No walls detected in any frame.")


if __name__ == "__main__":
    process_dicom(DICOM_PATH, OUTPUT_CSV)