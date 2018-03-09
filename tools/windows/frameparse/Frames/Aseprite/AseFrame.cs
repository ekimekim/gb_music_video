using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames.Aseprite
{
    public class AseFrame
    {
        public AseRect frame;
        public bool rotated;
        public bool trimmed;
        public AseRect spriteSourceSize;
        public AseVector2 sourceSize;
        // duration in milliseconds
        public int duration;
    }
}
