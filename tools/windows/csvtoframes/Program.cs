using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace csvtoframes
{
    public class Program
    {
        static Dictionary<string, int[]> Patterns = new Dictionary<string, int[]>()
        {
            { "trumpet_left", new int[] { 0, 1 } },
            { "drum", new int[] { 2, 3 } },
            { "trumpet_right", new int[] { 4, 5 } },
            { "picollo", new int[] { 6, 7 } },
            { "mixed", new int[] { 8, 9 } }
        };

        static string _lastInstrument;
        static int _lastFrame;

        static void Main(string[] args)
        {
            const int FrameMultiplier = 10;
            Patterns = Patterns.ToDictionary(p => p.Key, p => MultiplyFrames(p.Value, FrameMultiplier));

            var rows = File.ReadAllLines("src.csv")
                .Where(ParseableRow)
                .Select(r => 
                {
                    var cells = r.Split('\t');
                    return new { Time = ParseTime(cells[0]), Pattern = cells[1] };
                })
                .ToList();

            var writer = new StreamWriter("frameIds.asm");
            var now = TimeSpan.FromSeconds(0);

            for (int i = 0; i < rows.Count - 1; i++)
            {
                var row = rows[i];
                var nextRow = rows[i + 1];

                if (string.IsNullOrWhiteSpace(row.Pattern) || row.Pattern.Contains("//"))
                    continue;

                while(now < nextRow.Time)
                {
                    WriteInstrument(row.Pattern, writer, now);
                    now += TimeSpan.FromMilliseconds(16);
                }
            }
        }


        static void WriteInstrument(string instrument, StreamWriter writer, TimeSpan now)
        {
            int frame;
            if (instrument == _lastInstrument)
            {
                frame = _lastFrame + 1;
            }
            else
            {
                writer.WriteLine("; " + instrument + " at " + now);
                frame = 0;
            }

            frame = frame % Patterns[instrument].Length;

            var frameIndex = Patterns[instrument][frame];
            writer.WriteLine("db " + frameIndex);

            _lastInstrument = instrument;
            _lastFrame = frame;
        }

        static TimeSpan ParseTime(string time)
        {
            if(time.Contains(":"))
            {
                var parts = time.Split(':');

                return TimeSpan.FromMinutes(int.Parse(parts[0]))
                       + TimeSpan.FromSeconds(float.Parse(parts[1]));
            }
            else
            {
                return TimeSpan.FromSeconds(float.Parse(time));
            }
        }

        static int[] MultiplyFrames(int[] src, int count)
        {
            var frames = new List<int>();
            foreach (var frae in src)
            {
                for (int i = 0; i < count; i++)
                {
                    frames.Add(frae);
                }
            }
            return frames.ToArray();
        }

        static bool ParseableRow(string s)
        {
            if (string.IsNullOrWhiteSpace(s))
                return false;
            if (s.Contains("//"))
                return false;
            return true;
        }
    }
}
