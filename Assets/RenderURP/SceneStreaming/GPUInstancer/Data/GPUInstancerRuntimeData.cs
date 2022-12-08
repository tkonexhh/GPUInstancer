using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Inutan
{
    //最小渲染单元 一个物体可以由多个GPUInstancerRenderer组成
    public class GPUInstancerRenderer
    {
        public Mesh mesh;
        public List<Material> materials;
        public MaterialPropertyBlock mpb;
        public Matrix4x4 transformOffset;
        public int layer;
        public bool castShadows;
        public bool receiveShadows;


        //Indirect 独有的
        public int argsBufferOffset;

    }
}
