using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames
{
    public class TextureLoadOrder
    {
        // can't copy over boundaries 1024
        public int SourceIndex;
        public int DestinationBank;
        public int DestinationIndex;
        public int TexturesToCopy;

        const int LoadBoundaries = 102;

        public void ValidateBanks()
        {
            var startBank = SourceIndex / 1024;
            var endBank = (SourceIndex + TexturesToCopy) / 1024;

            if (startBank != endBank)
            {
                throw new Exception("Can't copy between banks");
            }
        }

        public override string ToString()
        {
            return string.Format("{0} to {1}, len {2}, bank {3}", SourceIndex, DestinationIndex, TexturesToCopy, DestinationBank);
        }
    }
}
