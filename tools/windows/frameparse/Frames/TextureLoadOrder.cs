using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames
{
    public class TextureLoadOrder
    {
        public int SourceIndex;
        public int DestinationBank;
        public int DestinationIndex;
        public int TexturesToCopy;

        public override string ToString()
        {
            return string.Format("{0} to {1}, len {2}, bank {3}", SourceIndex, DestinationIndex, TexturesToCopy, DestinationBank);
        }
    }
}
