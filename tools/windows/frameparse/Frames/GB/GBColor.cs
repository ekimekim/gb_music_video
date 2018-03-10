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
        public static Color ToColor(this GBColor color, GBPalette pallete = null)
        {
            pallete = pallete ?? GBPalette.Default;
            return pallete.Colors[(int)color];
        }
    }
}
