using animparse.Frames.GB;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames
{
    public class Frame
    {
        public const int Width = 21;
        public const int Height = 19;

        public const int MaxPaletteUpdates = 144;
        // Each unique load order consumes a tile
        public const int MaxLoadOrderTextures = 50;

        public const int TextureBanks = 2;

        public GBTile[,] TileUpdates;
        public Dictionary<int, GBPalette> PaletteUpdates;
        public List<TextureLoadOrder> LoadOrders;

        public int xScroll;
        public int yScroll;


        public Frame()
        {
            TileUpdates = new GBTile[Height, Width];
            PaletteUpdates = new Dictionary<int, GBPalette>();
            LoadOrders = new List<TextureLoadOrder>();

            xScroll = 0;
            yScroll = 0;
        }
    }
}