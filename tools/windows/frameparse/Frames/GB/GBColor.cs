using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames.GB
{
    public enum GBColor
    {
        Black = 0,
        DarkGrey = 1,
        LightGrey = 2,
        White = 3
    }

    public static class BGColorUtility
    {
        static Color[] DefaultPalette = new Color[]
        {
            Color.Black,
            Color.FromArgb(2 * 255 / 4, 2 * 255 / 4, 2 * 255 / 4),
            Color.FromArgb(3 * 255 / 3, 3 * 255 / 4, 3 * 255 / 4),
            Color.White,
        };

        public static Color ToColor(this GBColor color, Color[] pallete = null)
        {
            pallete = pallete ?? DefaultPalette;
            return pallete[(int)color];
        }
    }
}
