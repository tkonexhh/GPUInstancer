using System;
using System.Collections.Generic;
using System.Linq;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Events;

namespace GPUInstancer
{
    public static class GPUInstancerAPI
    {
        #region Global

        /// <summary>
        ///     <para>Main GPU Instancer initialization Method. Generates the necessary GPUInstancer runtime data from predifined 
        ///     GPU Instancer prototypes that are registered in the manager, and generates all necessary GPU buffers for instancing.</para>
        ///     <para>Use this as the final step after you setup a GPU Instancer manager and all its prototypes.</para>
        ///     <para>Note that you can also use this to re-initialize the GPU Instancer prototypes that are registered in the manager at runtime.</para>
        /// </summary>
        /// <param name="manager">The manager that defines the prototypes you want to GPU instance.</param>
        /// <param name="forceNew">If set to false the manager will not run initialization if it was already initialized before</param>
        public static void InitializeGPUInstancer(GPUInstancerManager manager, bool forceNew = true)
        {
            manager.InitializeRuntimeDataAndBuffers(forceNew);
        }

        /// <summary>
        ///     <para>Sets the active camera for all managers. This camera is used by GPU Instancer for various calculations (including culling operations). </para>
        ///     <para>Use this right after you add or change your camera at runtime. </para>
        /// </summary>
        /// <param name="camera">The camera that GPU Instancer will use.</param>
        public static void SetCamera(Camera camera)
        {
            if (GPUInstancerManager.activeManagerList != null)
                GPUInstancerManager.activeManagerList.ForEach(m => m.SetCamera(camera));
        }

        #endregion Global


    }
}
