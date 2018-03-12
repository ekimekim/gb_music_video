using animparse.Frames.GB;
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
    public static class FrameSerializer
    {
        public static void Export(string path, RomData romData)
        {
            var extension = Path.GetExtension(path);
            if (extension == ".json")
            {
                var json = JsonConvert.SerializeObject(romData, Formatting.Indented);
                File.WriteAllText(path, json);
            }
            else if (extension == ".asm")
            {
                var writer = new StreamWriter(path);
                writer.WriteRomData(romData);
                writer.Close();
            }
            else
            {
                throw new NotImplementedException(string.Format("extension {0} not implemented", extension));
            }
        }

        static void WriteRomData(this StreamWriter writer, RomData romData)
        {
            // ugg lets try
            // writer
            // 8 frames

            // tile
            // 8 palette
            // pick one

            writer.WritePaletteGroups(romData);

            writer.WriteTextures(romData);


            int a = 0;
        }

        static void WriteTextures(this StreamWriter writer, RomData romData)
        {
            writer.WriteComment(string.Format("Rom Textures {0}", romData.TextureData.Count));
            writer.WriteLine();

            for (int i = 0; i < romData.TextureData.Count; i++)
            {
                var texture = romData.TextureData[i];
                writer.WriteComment(string.Format("Rom Textures [{0}]", i));

                for (int rowIndex = 0; rowIndex < GBTexture.WidthPx; rowIndex++)
                {
                    writer.Write("dw `");
                    for (int colIndex = 0; colIndex < GBTexture.WidthPx; colIndex++)
                    {
                        writer.Write(((int)texture.Get(rowIndex, colIndex)).ToString());
                    }
                    writer.WriteLine(); // finish
                }
                writer.WriteLine();
            }
        }

        static void WritePaletteGroups(this StreamWriter writer, RomData romData)
        {
            var paletteGroups = romData.PaletteData.Take(4).ToArray();
            writer.WriteComment("Palatte Groups 1 total");
            writer.WriteLine();

            {
                writer.WriteComment("Palatte Groups [0]");
                writer.WritePalette(paletteGroups.First());
                writer.WriteLine();
            }
        }

        static void WritePalette(this StreamWriter writer, GBPalette palette)
        {
            // output 5 bit colors
            // 0bbb bbgg gggr rrrr
            foreach (var color in palette.Colors.Select(GetBGBytes))
            {
                var colorMask = (color[0]) | (color[1] << 5) | (color[2] << 10);

                var line = "dw `";
                for (int i = 15; i > 0; --i)
                {
                    var writerMask = 1 << i;
                    if ((colorMask & writerMask) == 0)
                        line += "0";
                    else
                        line += "1";
                }

                writer.WriteLine(line);
            }
        }

        static byte[] GetBGBytes(Color col)
        {
            return new byte[]
            {
                Int8ToInt5(col.R),
                Int8ToInt5(col.G),
                Int8ToInt5(col.B)
            };
            //return new int[]
            //{
            //    32 * ((13 * col.R) + (2*col.G) + col.B) / (2 * 255),
            //    32 * ((6 * col.G) + (2 * col.B)) / 255,
            //    32 * ((3 * col.R) + (2 * col.G) + (11 * col.B)) / (2 * 255),
            //};
        }

        static byte Int8ToInt5(int src)
        {
            return (byte)(31 * src / 255);
        }

        static void WriteComment(this StreamWriter writer, string msg)
        {
            writer.WriteLine(";" + msg);
        }

        static void WriteDw(this StreamWriter writer, string msg)
        {
            writer.WriteLine(";" + msg);
        }
    }
}
