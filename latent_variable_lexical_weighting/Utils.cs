using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace lvlw
{
    public class Utils
    {
        public static IEnumerable<List<T>> Transpose<T>(params IEnumerable<T>[] e)
        {
            var le = new List<IEnumerator<T>>(e.Select(x => x.GetEnumerator()));
            while (le.All(x => x.MoveNext()))
                yield return new List<T>(le.Select(x => x.Current));
        }

        public static IEnumerable<WordAlignment> Alignments(string s, string t, string a)
        {
            foreach (var l in Transpose(GetLines(s), GetLines(t), GetLines(a)))
            {
                yield return new WordAlignment(l[0], l[1], l[2]);
            }
        }

        public static IEnumerable<string> GetLines(string filename)
        {
            using (var sr = new StreamReader(filename))
            {
                string line;
                while (null != (line = sr.ReadLine()))
                    yield return line;
            }
        }
    }
}
