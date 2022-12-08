using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Inutan
{
    public class GPUInstancerConstants
    {
        #region Stride Sizes
        // Compute buffer stride sizes
        public static readonly int STRIDE_SIZE_MATRIX4X4 = 64;   //16*sizeof(float)
        public static readonly int STRIDE_SIZE_INT = 4;
        public static readonly int STRIDE_SIZE_FLOAT = 4;
        public static readonly int STRIDE_SIZE_FLOAT4 = 16;
        #endregion Stride Sizes



    }
}
