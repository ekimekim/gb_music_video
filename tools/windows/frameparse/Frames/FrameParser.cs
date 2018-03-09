using animparse.Frames.Aseprite;
using animparse.Frames.Bitmap;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames
{
    public class FrameParser
    {
        public Frame[] Parse(string path)
        {
            var bitmap = new System.Drawing.Bitmap(path);

            var bitmapFrames = BitmapTexture.FromBitmap(bitmap);
            


            return null;
        }

        public void Export(string path, Frame[] frames)
        {

        }
    }
}
