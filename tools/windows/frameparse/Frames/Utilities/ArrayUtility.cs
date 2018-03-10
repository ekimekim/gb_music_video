using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames.Utilities
{
    public static class ArrayUtility
    {
        public static IEnumerable<Vec2> ForEach(int height, int width)
        {
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    yield return new Vec2(x, y);
                }
            }
        }
    }

    public struct Vec2
    {
        public int x;
        public int y;

        public Vec2(int x, int y)
        {
            this.x = x;
            this.y = y;
        }
    }
}
