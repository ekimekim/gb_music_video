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
        public const int WidthPx = 8;
        public GBColor[][] Colors;

        public GBTexture()
        {
            Colors = new GBColor[WidthPx][];
            for (int yCell = 0; yCell < WidthPx; yCell++)
            {
                Colors[yCell] = new GBColor[WidthPx];
            }
        }

        public GBColor Get(int x, int y)
        {
            return Colors[y][x];
        }

        public void Set(int x, int y, GBColor color)
        {
            Colors[y][x] = color;
        }

        public bool Match(GBTexture other)
        {
            for (int y = 0; y < WidthPx; y++)
            {
                for (int x = 0; x < WidthPx; x++)
                {
                    if(Colors[y][x] != other.Colors[y][x])
                    {
                        return false;
                    }
                }
            }

            return true;
        }
    }
}
