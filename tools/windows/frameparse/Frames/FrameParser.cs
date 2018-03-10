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
                AddFrame(romData, bitmapFrame);
            }

            return romData;
        }

        public static void AddFrame(RomData romData, BitmapTexture[,] bitmapFrame)
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
                romData.UpsertPalette(palette, pushedPalettes);
                romData.UpsertTexture(texture, pushedTextures);

                // Add tile to frame
                var tile = new GBTile();
                tile.Palette = palette;
                tile.Texture = texture;
                frame.TileUpdates[vec.y, vec.x] = tile;
            }

            pushedPalettes.Sort();
            pushedTextures.Sort();

            // palettes changes
            frame.PaletteUpdates = pushedPalettes.ToDictionary(i => i, i => romData.PaletteData[i]);

            // texture changes
            frame.LoadOrders = GetLoads(pushedTextures).ToList();

            int foo = 0;
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

            TextureLoadOrder order = null;
            int? lastIndex = null;

            foreach (var index in tiles)
            {
                order = order ?? new TextureLoadOrder()
                {
                    DestinationBank = 0,
                    DestinationIndex = index,
                    SourceIndex = index,
                    TexturesToCopy = 1,
                };
                lastIndex = lastIndex ?? index;

                if (index == lastIndex.Value + 1)
                {
                    lastIndex = index;
                    order.TexturesToCopy += 1;
                }
                else
                {
                    yield return order;
                    order = null;
                    lastIndex = null;
                }
            }

            if (order != null)
                yield return order;
        }

        public void Export(string path, RomData frames)
        {
            var extension = Path.GetExtension(path);
            if (extension == ".json")
            {
                var json = JsonConvert.SerializeObject(frames);
                File.WriteAllText(path, json);
            }
            else
            {
                throw new NotImplementedException(string.Format("extension {0} not implemented", extension));
            }
        }
    }
}
