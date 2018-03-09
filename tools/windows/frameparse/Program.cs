using animparse.Frames;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse
{
    class Program
    {
        static void Main(string[] args)
        {
            var from = StripQuotes(args[0]);
            var to = StripQuotes(args[1]);

            var parser = new FrameParser();
            var frames = parser.Parse(from);
            parser.Export(to, frames);
        }

        static string StripQuotes(string path)
        {
            if(path.Length >= 2 && path[0] == '\"' && path[path.Length -1] == '\"')
            {
                path = path.Substring(1, path.Length - 2);
            }
            return path;
        }
    }
}
