using animparse.Frames.Utilities;
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

        public static List<BitmapTexture[,]> FromBitmap(System.Drawing.Bitmap bitmap, bool includeScroll = false)
        {
            int offsetScroll = includeScroll ? 0 : 1;

            var frames = new List<BitmapTexture[,]>();
            for (int xFramePixel = 0; xFramePixel < bitmap.Width; xFramePixel += FramePixelWidth)
            {
                var bitmapTextures = new BitmapTexture[Frame.Height, Frame.Width];

                foreach (var vec3 in ArrayUtility.ForEach(Frame.Height - offsetScroll, Frame.Width - offsetScroll))
                {
                    var xPixelOffset = xFramePixel + (vec3.x * BitmapTexture.WidthPx);
                    var yPixelOffset = (vec3.y * BitmapTexture.WidthPx);

                    bitmapTextures[vec3.y, vec3.x] = BitmapTexture.FromBitmap(bitmap, xPixelOffset, yPixelOffset);
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
