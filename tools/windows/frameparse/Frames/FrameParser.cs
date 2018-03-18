using animparse.Frames.Aseprite;
using animparse.Frames.Bitmap;
using animparse.Frames.GB;
using animparse.Frames.Utilities;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames
{
    public class FrameParser
    {
        public RomData Parse(string path)
        {
            var bitmap = new System.Drawing.Bitmap(path);

            var bitmapFrames = BitmapTexture.FromBitmap(bitmap);

            var romData = new RomData()
            {
                Frames = new List<Frame>(),
                PaletteData = new List<GBPalette>(),
                TextureData = new List<GBTexture>(),
            };

            foreach (var bitmapFrame in bitmapFrames)
            {
                var frame = ParseFrame(romData, bitmapFrame);

                frame.Index = romData.Frames.Count;
                frame.Duration = 16 * 2;

                romData.Frames.Add(frame);
            }

            return romData;
        }

        public static Frame ParseFrame(RomData romData, BitmapTexture[,] bitmapFrame)
        {
            var frame = new Frame();

            // parse palettes and textures
            GBPalette[,] palettes = new GBPalette[Frame.Height, Frame.Width];
            GBTexture[,] textures = new GBTexture[Frame.Height, Frame.Width];

            var pushedPalettes = new List<int>();
            var pushedTextures = new List<int>();

            foreach (var vec in ArrayUtility.ForEach(Frame.Height, Frame.Width))
            {
                var palette = GetPalette(bitmapFrame[vec.y, vec.x]);
                var texture = GetTexture(bitmapFrame[vec.y, vec.x], palette);

                palettes[vec.y, vec.x] = GetPalette(bitmapFrame[vec.y, vec.x]);
                textures[vec.y, vec.x] = GetTexture(bitmapFrame[vec.y, vec.x], palettes[vec.y, vec.x]);

                // Add Palette / Texture to rom
                var paletteIndex = romData.UpsertPalette(palette, pushedPalettes);
                var textureIndex = romData.UpsertTexture(texture, pushedTextures);

                // Add tile to frame
                var tile = new GBTile();
                tile.Palette = romData.PaletteData[paletteIndex];
                tile.Texture = romData.TextureData[textureIndex];
                frame.TileUpdates[vec.y, vec.x] = tile;
            }

            foreach (var vec in ArrayUtility.ForEach(Frame.Height, Frame.Width))
            {
                var index = romData.TextureData.IndexOf(frame.TileUpdates[vec.y, vec.x].Texture);
                if (index == -1)
                    throw new Exception("Texture missing at " + vec.x + ", " + vec.y);
            }

            pushedPalettes.Sort();
            pushedTextures.Sort();

            // palettes changes
            frame.PaletteUpdates = pushedPalettes.ToDictionary(i => i, i => romData.PaletteData[i]);

            // texture changes
            frame.LoadOrders = GetLoads(pushedTextures).ToList();

            return frame;
        }

        static GBTexture GetTexture(BitmapTexture bitmapTexture, GBPalette palette)
        {
            if (bitmapTexture == null)
                return GBTexture.Default;

            var tex = new GBTexture();

            for (int y = 0; y < GBTexture.WidthPx; y++)
            {
                for (int x = 0; x < GBTexture.WidthPx; x++)
                {
                    var color = bitmapTexture.Get(x, y);
                    var bgColor = palette.GetGBColor(color);
                    tex.Set(x, y, bgColor);
                }
            }

            return tex;
        }

        static GBPalette GetPalette(BitmapTexture texture)
        {
            if (texture == null)
                return GBPalette.Default;

            var colors = new List<Color>();
            for (int y = 0; y < BitmapTexture.WidthPx; y++)
            {
                for (int x = 0; x < BitmapTexture.WidthPx; x++)
                {
                    var col = texture.Get(x, y);
                    if (colors.Contains(col) == false)
                        colors.Add(col);
                }
            }

            colors = colors.SortColors();

            while (colors.Count < GBPalette.MaxLength)
                colors.Add(Color.Pink);

            return new GBPalette(colors.Take(GBPalette.MaxLength).ToArray());
        }

        static IEnumerable<TextureLoadOrder> GetLoads(List<int> tiles)
        {
            if (tiles.Any() == false)
                yield break;

            List<List<int>> strips = new List<List<int>>();
            strips.Add(new List<int>());

            foreach (var index in tiles)
            {
                var lastStrip = strips.Last();
                int? lastIndex = lastStrip.Any() ? lastStrip.Last() : (int?)null;

                if (lastIndex.HasValue && index == lastIndex + 1)
                {
                    lastStrip.Add(index);
                }
                else
                {
                    strips.Add(new List<int>() { index });
                }
            }

            foreach (var strip in strips.Where(s => s.Any()))
            {
                var load = new TextureLoadOrder();
                load.DestinationBank = 0;
                load.DestinationIndex = strip.First();
                load.SourceIndex = strip.First();
                load.TexturesToCopy = strips.Count;

                load.ValidateBanks();

                yield return load;
            }
        }

    }
}
