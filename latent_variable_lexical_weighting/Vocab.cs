using System;
using System.Collections.Generic;

namespace lvlw
{
    public class Vocab
    {
        public int this[string s]
        {
            get
            {
                int id;
                if (m_map.TryGetValue(s, out id)) return id;
                id = m_array.Count;
                m_array.Add(s);
                m_map[s] = id;
                return id;
            }
        }

        public string this[int id]
        {
            get
            {
                if (id < 0 || id >= m_array.Count)
                    throw new Exception("out of range vocab id");
                return m_array[id];
            }
        }

        Dictionary<string, int> m_map = new Dictionary<string, int>();
        List<string> m_array = new List<string>();
    }
}
