using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames.Bitmap
{
    public static class ColorUtility
    {
        public static List<Color> SortColors(this List<Color> colors)
        {
            return colors.OrderBy(c => c.R).ThenBy(c => c.G).ThenBy(c => c.B).ToList();
        }
    }
}
