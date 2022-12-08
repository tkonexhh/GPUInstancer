using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class InutanBloomMaskMeshCollection : MonoBehaviour {

    [Serializable]
    public struct MeshCollection {
        public Renderer render;
        public MeshFilter meshFilter;
        public SkinnedMeshRenderer skinnedMeshFilter;
        public Transform transform;
    }


    // [HideInInspector]
    public List<MeshCollection> m_MeshCollections = new List<MeshCollection>();

    public InutanBloomMask m_Mask;

#if UNITY_EDITOR
    private void OnDrawGizmosSelected() { OnValidate(); }
    private void OnValidate()
    {
        if (Application.isPlaying) return;

        m_Mask = FindObjectOfType<InutanBloomMask>(true);
        UpdateMeshCollections();
    }
#endif
    private void Awake() 
    {
       m_Mask?.AddCollection(this);
    }

    private void OnEnable() 
    {
    //    UpdateMeshCollections();
       m_Mask?.AddCollection(this);
    }

    private void OnDisable()
    {
       m_Mask?.RemoveCollection(this);
    }

    private void OnDestroy() 
    {
       m_Mask?.RemoveCollection(this);
    }

    public void UpdateMeshCollections() {
        m_MeshCollections.Clear();
        FindMeshes(m_MeshCollections, this.transform);
    }


    private static void FindMeshes(ICollection<MeshCollection> meshes, Transform go) {
        MeshCollection mesh;
        if (TryGetMesh(go, out mesh))
            meshes.Add(mesh);
        for (int i = 0; i < go.childCount; ++i) {
            var child = go.GetChild(i);
            if (child.GetComponent<InutanBloomMaskMeshCollection>() == null)
                FindMeshes(meshes, child);
        }
    }

    private static bool TryGetMesh(Transform go, out MeshCollection mesh) {
        mesh = new MeshCollection();

        var rd = go.GetComponent<Renderer>();
        if (rd != null)
            mesh.render = rd;

        var mf = go.GetComponent<MeshFilter>();
        if (mf != null)
            mesh.meshFilter = mf;

        var smf = go.GetComponent<SkinnedMeshRenderer>();
        if (smf != null)
            mesh.skinnedMeshFilter = smf;

        if (mesh.meshFilter != null || mesh.skinnedMeshFilter != null) {
            mesh.transform = go;
            return true;
        }
        return false;
    }



}
