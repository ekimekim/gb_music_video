using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames.GB
{
    /// <summary>
    /// Also know as a Tile
    /// </summary>
    public class GBTexture
    {
        public int WidthPx = 8;
        public GBColor[][] Colors;

        public GBColor Get(int x, int y)
        {
            return Colors[y][x];
        }

        public void Set(int x, int y, GBColor color)
        {
            Colors[y][x] = color;
        }
    }
}
