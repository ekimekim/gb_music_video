using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames.Bitmap
{
    public class BitmapTexture
    {
        public const int WidthPx = 8;
        const int FramePixelWidth = Frame.Width * WidthPx;

        System.Drawing.Bitmap _bitmap;
        int _xOffset;
        int _yOffset;

        public static List<BitmapTexture[][]> FromBitmap(System.Drawing.Bitmap bitmap)
        {
            var frames = new List<BitmapTexture[][]>();
            for (int xFramePixel = 0; xFramePixel < bitmap.Width; xFramePixel += FramePixelWidth)
            {
                var bitmapTextures = new BitmapTexture[Frame.Height][];

                for (int yCell = 0; yCell < Frame.Height; yCell++)
                {
                    bitmapTextures[yCell] = new BitmapTexture[Frame.Width];
                    for (int xCell = 0; xCell < Frame.Width; xCell++)
                    {
                        var xPixelOffset = xFramePixel + (xCell * BitmapTexture.WidthPx);
                        var yPixelOffset = yCell * BitmapTexture.WidthPx;

                        bitmapTextures[yCell][xCell] = BitmapTexture.FromBitmap(bitmap, xPixelOffset, yPixelOffset);
                    }
                }

                frames.Add(bitmapTextures);
            }

            return frames;
        }

        public static BitmapTexture FromBitmap(System.Drawing.Bitmap bitmap, int xOffset, int yOffset)
        {
            var texture = new BitmapTexture()
            {
                _bitmap = bitmap,
                _xOffset = xOffset,
                _yOffset = yOffset
            };
            return texture;
        }

        public Color Get(int x, int y)
        {
            return _bitmap.GetPixel(x + _xOffset, y + _yOffset);
        }
    }
}
