using System;
using System.Collections.Generic;

namespace lvlw
{
    public class AutoInitDict<K, V> : Dictionary<K, V>
    {
        public AutoInitDict(Func<V> c)
        {
            creator = c;
        }

        Func<V> creator;

        public new V this[K key]
        {
            get
            {
                V v;
                if (!TryGetValue(key, out v))
                {
                    this.Add(key, v = creator());
                }
                return v;
            }
        }
    }
}
