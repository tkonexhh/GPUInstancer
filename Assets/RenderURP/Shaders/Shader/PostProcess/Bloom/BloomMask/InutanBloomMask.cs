using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

[RequireComponent(typeof(Camera)), ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class InutanBloomMask : MonoBehaviour {

    public List<InutanBloomMaskMeshCollection> m_Collection = new List<InutanBloomMaskMeshCollection>();
 
    private Camera m_Camera;
    private CameraEvent m_CameraEvent = CameraEvent.BeforeImageEffects;

    private CommandBuffer m_CmdCopy;

    private CommandBuffer m_CmdMask;

    private CommandBuffer m_CmdBack;

    private int m_RTIdCopy = Shader.PropertyToID("BloomMaskRT_Copy");
    private int m_RTIdMask = Shader.PropertyToID("BloomMaskRT_Mask");

    private int m_IdCopy = Shader.PropertyToID("_BloomMaskCopyTex");
    private int m_IdMask = Shader.PropertyToID("_BloomMaskTex");

    private string m_ShaderName = "Hidden/PostProcessing/Inutan/BloomMask";
    private Shader m_Shader;

    private Material m_Mat;
    private MaterialPropertyBlock m_Properties;

    private void Awake() 
    {
        m_Camera = GetComponent<Camera>();
    }

    private void OnEnable() 
    {
        Init();
    }

    private void OnDisable() 
    {
       Dispose();
    }

    void Init()
    {
        if(m_Mat == null)
        {
            if(m_Shader == null)
                m_Shader = Shader.Find(m_ShaderName);
            m_Mat = new Material(m_Shader) { hideFlags = HideFlags.DontSave };
        }

        if(m_CmdCopy == null)
            m_CmdCopy = new CommandBuffer() { name = "BloomMaskCopy" };
        if(m_CmdMask == null)
            m_CmdMask = new CommandBuffer() { name = "BloomMask" };
        if(m_CmdBack == null)
            m_CmdBack = new CommandBuffer() { name = "BloomMaskBack" };

        var buffers = m_Camera.GetCommandBuffers(m_CameraEvent);
        m_Camera.RemoveCommandBuffers(m_CameraEvent);
        m_Camera.AddCommandBuffer(m_CameraEvent, m_CmdCopy);
        m_Camera.AddCommandBuffer(m_CameraEvent, m_CmdMask);
        m_Camera.AddCommandBuffer(m_CameraEvent, m_CmdBack);
        foreach (var b in buffers) {
            m_Camera.AddCommandBuffer(m_CameraEvent, b);
        }
    }

    void Dispose()
    {
        if (m_CmdCopy != null)
        {
            m_Camera.RemoveCommandBuffer(m_CameraEvent, m_CmdCopy);
            m_CmdCopy.Dispose();
            m_CmdCopy = null;
        }

        if (m_CmdMask != null)
        {
            m_Camera.RemoveCommandBuffer(m_CameraEvent, m_CmdMask);
            m_CmdMask.Dispose();
            m_CmdMask = null;
        }

        if (m_CmdBack != null)
        {
            m_Camera.RemoveCommandBuffer(m_CameraEvent, m_CmdBack);
            m_CmdBack.Dispose();
            m_CmdBack = null;
        }

        if(m_Mat != null)
        {
            if (Application.isPlaying)
                Destroy(m_Mat);
            else
                DestroyImmediate(m_Mat);
        }
    }


    public void AddCollection(InutanBloomMaskMeshCollection value)
    {
        if(!m_Collection.Contains(value))
        {
            m_Collection.Add(value);
        }
    }

    public void RemoveCollection(InutanBloomMaskMeshCollection value)
    {
        m_Collection.Remove(value);
    }

    private void OnPreRender() 
    {
        var sourceFormat = m_Camera.allowHDR ? RuntimeUtilities.defaultHDRRenderTextureFormat : RenderTextureFormat.Default;
        var width = m_Camera.pixelWidth;
        var height = m_Camera.pixelHeight;

        // Copy
        m_CmdCopy.Clear();
        m_CmdCopy.GetTemporaryRT(m_RTIdCopy, width, height, 0, FilterMode.Bilinear, sourceFormat);
        m_CmdCopy.SetGlobalTexture(m_IdCopy, BuiltinRenderTextureType.CurrentActive);
        m_CmdCopy.Blit(BuiltinRenderTextureType.CurrentActive, m_RTIdCopy, m_Mat, 0);
        
        m_CmdCopy.SetGlobalTexture(m_IdCopy, m_RTIdCopy);

        // Draw mask
        m_CmdMask.Clear();
        m_CmdMask.ClearRenderTarget(false, true, Color.clear);

        foreach (var cot in m_Collection) {
            if (cot == null || !cot.isActiveAndEnabled) continue;

            foreach (var var in cot.m_MeshCollections) 
            {
                if(!var.render.enabled) continue;

                Mesh mesh = null;
                if(var.meshFilter != null)
                    mesh = var.meshFilter.sharedMesh;
                if(var.skinnedMeshFilter != null)
                    mesh = var.skinnedMeshFilter.sharedMesh;

                if(mesh == null) continue;

                for (int i = 0; i < mesh.subMeshCount; ++i)
                {
                    if(m_Properties == null)
                        m_Properties = new MaterialPropertyBlock();
                    m_Properties.Clear();
                    float intensity = 0;
                    if(var.render.sharedMaterial.HasProperty("_BloomIntensity"))
                        intensity = var.render.sharedMaterial.GetFloat("_BloomIntensity");
                    m_Properties.SetFloat("_BloomIntensity", intensity);
                    m_CmdMask.DrawMesh(mesh, var.transform.localToWorldMatrix, m_Mat, i, 1, m_Properties);
                }
            }
        }

        m_CmdMask.GetTemporaryRT(m_RTIdMask, width, height);
        m_CmdMask.SetGlobalTexture(m_IdMask, BuiltinRenderTextureType.CurrentActive);
        m_CmdMask.Blit(null, m_RTIdMask, m_Mat, 2);

        m_CmdMask.SetGlobalTexture(m_IdMask, m_RTIdMask);

     
        // Copy Back
        m_CmdBack.Clear();
        m_CmdBack.Blit(null, BuiltinRenderTextureType.CurrentActive, m_Mat, 0);

        // 
        m_CmdMask.ReleaseTemporaryRT(m_RTIdMask);
        m_CmdBack.ReleaseTemporaryRT(m_RTIdCopy);
    }
}
