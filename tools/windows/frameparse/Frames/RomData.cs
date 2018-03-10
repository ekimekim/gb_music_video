using animparse.Frames.GB;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames
{
    public class RomData
    {
        public List<GBPalette> PaletteData;
        public List<GBTexture> TextureData;
        public List<Frame> Frames;

        public int UpsertPalette(GBPalette palette, List<int> pushedPalettes)
        {
            for (int i = 0; i < PaletteData.Count; i++)
            {
                if (PaletteData[i].Match(palette))
                    return i;
            }

            PaletteData.Add(palette);
            var index = PaletteData.Count - 1;
            pushedPalettes.Add(index);
            return index;
        }

        public int UpsertTexture(GBTexture texture, List<int> pushedTextures)
        {
            for (int i = 0; i < PaletteData.Count; i++)
            {
                if (TextureData[i].Match(texture))
                    return i;
            }

            TextureData.Add(texture);
            var index = PaletteData.Count - 1;
            pushedTextures.Add(index);
            return index;
        }
    }
}
