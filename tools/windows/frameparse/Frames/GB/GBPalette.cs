using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames.GB
{
    public class GBPalette
    {
        public const int MaxLength = 4;
        public static GBPalette Default = new GBPalette(new Color[]
        {
                Color.Black,
                Color.FromArgb(2 * 255 / 4, 2 * 255 / 4, 2 * 255 / 4),
                Color.FromArgb(3 * 255 / 3, 3 * 255 / 4, 3 * 255 / 4),
                Color.White,
        });
        public Color[] Colors;

        public GBPalette(params Color[] colors)
        {
            Colors = colors;
        }

        public Color Get(int index)
        {
            return Colors[index];
        }

        public Color GetColor(GBColor color)
        {
            return Get((int)color);
        }

        public GBColor GetGBColor(Color color)
        {
            var index = Array.IndexOf(Colors, color);
            return (GBColor)index;
        }

        public bool Match(GBPalette other)
        {
            for (int i = 0; i < MaxLength; i++)
            {
                if (Colors[i] != other.Colors[i])
                    return false;
            }
            return true;
        }
    }
}
