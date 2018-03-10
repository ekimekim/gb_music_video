using animparse.Frames.GB;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames
{
    public class ScreenState
    {
        public const int MaxTextureBank = 2;
        public const int MaxTextures = 255;
        public const int MaxPalettes = 8;

        public GBTile[][] Tiles;
        public GBTexture[][] Textures;
        public GBPalette[] Palette;

        public ScreenState()
        {
            Tiles = new GBTile[Frame.Height][];
            for (int y = 0; y < Frame.Height; y++)
            {
                Tiles[y] = new GBTile[Frame.Width];
                for (int x = 0; x < Frame.Width; x++)
                {
                    Tiles[y][x] = new GBTile();
                }
            }

            Textures = new GBTexture[2][];
            for (int y = 0; y < MaxTextureBank; y++)
            {
                Textures[y] = new GBTexture[MaxTextures];
            }

            Palette = new GBPalette[MaxPalettes];
        }
    }
}
