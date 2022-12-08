using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Sirenix.OdinInspector;
#if UNITY_EDITOR
using Sirenix.OdinInspector.Editor;
using Sirenix.Utilities.Editor;
using UnityEditor;
#endif
using System.Reflection;

[ExecuteInEditMode]
public class SkyControllerOpt : MonoBehaviour
{
    [FoldoutGroup("天空资源配置"), LabelText("太阳")]
    public Transform m_SunTransform;
    [FoldoutGroup("天空资源配置"), LabelText("月亮")]
    public Transform m_MoonTransform;
    [FoldoutGroup("天空资源配置"), LabelText("天穹")]
    public Transform m_DomeTransform;
    [FoldoutGroup("天空资源配置"), LabelText("云")]
    public Transform m_CloudTransform;
    [FoldoutGroup("天空资源配置"), LabelText("星星")]
    public Transform m_StarsTransform;

    [FoldoutGroup("天空资源配置"), LabelText("月亮贴图")]
    public Texture m_MoonTexture;
    [FoldoutGroup("天空资源配置"), LabelText("云贴图")]
    public Texture m_CloudTexture;
    // ----------------------------------------------------
    [FoldoutGroup("全局参数"), LabelText("使用时间轴"), OnValueChanged("OnUseTimeline")]
    public bool m_UseTimeline = false;
    [FoldoutGroup("全局参数"), LabelText("时间轴"), Range(0, 24), ShowIf("m_UseTimeline"), OnValueChanged("OnTimeChanged")]
    public float m_Timeline = 0.0f;

    [FoldoutGroup("全局参数"), LabelText("使用真实的月亮位置")]
    public bool m_UseRealisticMoonPosition = false;

    [FoldoutGroup("全局参数"), LabelText("经度")]
    public float m_Longitude = 0.0f;
    [FoldoutGroup("全局参数"), LabelText("纬度")]
    public float m_Latitude = 0.0f;
    [FoldoutGroup("全局参数"), LabelText("时区")]
    public float m_UTC = 0.0f;
    [FoldoutGroup("全局参数"), LabelText("年")]
    public int m_Year = 2000;
    [FoldoutGroup("全局参数"), LabelText("月")]
    public int m_Month = 6;
    [FoldoutGroup("全局参数"), LabelText("日")]
    public int m_Day = 23;


    [FoldoutGroup("参数列表")]
    [InlineEditor(InlineEditorModes.GUIOnly), LabelText("配置")]
    public List<SkyAssetOpt> m_AssetList;

    // --------------------------------------------------------------------------------

    private MaterialPropertyBlock m_PropertyBlock;
    private MeshRenderer m_SkyRenderer;
    private MeshRenderer m_CloudRenderer;
    private MeshRenderer m_StarsRenderer;

	
    // --------------------------------------------------------------------------------
    private float m_LerpValue;
    private float m_MoonAboveHorizon;
    private Vector3 m_LocalSunDirection;
    private Vector3 m_LocalMoonDirection;
    private Vector3 m_CloudUV;

    static class Uniforms
    {
        internal static readonly int _RayleighMultiplier = Shader.PropertyToID("_RayleighMultiplier");
        internal static readonly int _MieMultiplier = Shader.PropertyToID("_MieMultiplier");
        // internal static readonly int _Directionality = Shader.PropertyToID("_Directionality");
        internal static readonly int _Contrast = Shader.PropertyToID("_Contrast");
        internal static readonly int _Brightness = Shader.PropertyToID("_Brightness");
        //
        internal static readonly int _DaySkyColor = Shader.PropertyToID("_DaySkyColor");
        internal static readonly int _SunHaloSize = Shader.PropertyToID("_SunHaloSize");
        internal static readonly int _SunColor = Shader.PropertyToID("_SunColor");
        internal static readonly int _SunSize = Shader.PropertyToID("_SunSize");
        //
        internal static readonly int _NightSkyColor = Shader.PropertyToID("_NightSkyColor");
        internal static readonly int _MoonHaloSize = Shader.PropertyToID("_MoonHaloSize");
        internal static readonly int _MoonHaloColor = Shader.PropertyToID("_MoonHaloColor");
        internal static readonly int _MoonColor = Shader.PropertyToID("_MoonColor");
        internal static readonly int _MoonSize = Shader.PropertyToID("_MoonSize");
        //
        internal static readonly int _GroundColor = Shader.PropertyToID("_GroundColor");
        //
        internal static readonly int _LocalSunDirection = Shader.PropertyToID("_LocalSunDirection");
        internal static readonly int _LocalMoonDirection = Shader.PropertyToID("_LocalMoonDirection");
        //
        internal static readonly int _WorldToMoonMatrix = Shader.PropertyToID("_WorldToMoonMatrix");
        internal static readonly int _MoonTexture = Shader.PropertyToID("_MoonTexture");

        // -------------------------------------------------------------------------
        internal static readonly int _CloudSize = Shader.PropertyToID("_CloudSize");
        internal static readonly int _CloudWind = Shader.PropertyToID("_CloudWind");
        internal static readonly int _CloudNightColor = Shader.PropertyToID("_CloudNightColor");
        internal static readonly int _CloudDayColor = Shader.PropertyToID("_CloudDayColor");
        internal static readonly int _CloudScattering = Shader.PropertyToID("_CloudScattering");
        internal static readonly int _CloudBrightness = Shader.PropertyToID("_CloudBrightness");
        internal static readonly int _CloudColoring = Shader.PropertyToID("_CloudColoring");
        internal static readonly int _CloudSkyColorIntensity = Shader.PropertyToID("_CloudSkyColorIntensity");
        internal static readonly int _CloudOpacity = Shader.PropertyToID("_CloudOpacity");
        internal static readonly int _CloudCoverage = Shader.PropertyToID("_CloudCoverage");
        internal static readonly int _CloudDensity = Shader.PropertyToID("_CloudDensity");
        internal static readonly int _CloudAttenuation = Shader.PropertyToID("_CloudAttenuation");
        internal static readonly int _CloudSaturation = Shader.PropertyToID("_CloudSaturation");
        internal static readonly int _CloudClip = Shader.PropertyToID("_CloudClip");


        internal static readonly int _CloudTexture = Shader.PropertyToID("_CloudTexture");

        //
        internal static readonly int _StarBrightness = Shader.PropertyToID("_StarBrightness");
        internal static readonly int _StarSize = Shader.PropertyToID("_StarSize");

    }

    private SkyAssetOpt m_AssetLast;
    private SkyAssetOpt m_AssetNext;
    private float m_TimeLerp;

    public void OnUseTimeline()
    {
        if(m_UseTimeline)
        {
            if(m_AssetList != null && m_AssetList.Count > 0)
                m_AssetList.Sort((x, y) => x.Hour.CompareTo(y.Hour));

            OnTimeChanged();
        }
    }

    public void OnTimeChanged()
    {
        if(!m_UseTimeline)
            return;
        if(m_AssetList == null || m_AssetList.Count <= 0)
            return;

        for(int i = 0; i < m_AssetList.Count; i ++)
        {
            if(m_Timeline <= m_AssetList[i].Hour)
            {
                if(i == 0)
                {
                    m_AssetLast = m_AssetList[m_AssetList.Count - 1];
                    m_AssetNext = m_AssetList[i];
                    m_TimeLerp = (m_Timeline - m_AssetLast.Hour + 24) / (m_AssetNext.Hour - m_AssetLast.Hour + 24);
                }
                else
                {
                    m_AssetLast = m_AssetList[i-1];
                    m_AssetNext = m_AssetList[i];
                    m_TimeLerp = (m_Timeline - m_AssetLast.Hour) / (m_AssetNext.Hour - m_AssetLast.Hour);
                }
                break;
            }
            if(m_Timeline > m_AssetList[m_AssetList.Count - 1].Hour)
            {
                m_AssetLast = m_AssetList[m_AssetList.Count - 1];
                m_AssetNext = m_AssetList[0];
                m_TimeLerp = (m_Timeline - m_AssetLast.Hour) / (m_AssetNext.Hour - m_AssetLast.Hour + 24);
            }
        }
    }

    private SkyAssetOpt GetAsset()
    {
        if(m_AssetList != null && m_AssetList.Count > 0)
            return m_AssetList[0];
        
        return null;
    }

    private object GetValue(SkyAssetOpt asset, string name)
    {
        return asset.GetType().GetField(name).GetValue(asset);
    }

    private float GetFloatCurrent(string name)
    {
        float last = (float)GetValue(m_AssetLast, name);
        float next = (float)GetValue(m_AssetNext, name);

        return Mathf.Lerp(last, next, m_TimeLerp);
    }

    private Vector3 GetVectorCurrent(string name)
    {
        Vector3 last = (Vector3)GetValue(m_AssetLast, name);
        Vector3 next = (Vector3)GetValue(m_AssetNext, name);

        return Vector3.Lerp(last, next, m_TimeLerp);
    }

    private Color GetColorCurrent(string name)
    {
        Color last = (Color)GetValue(m_AssetLast, name);
        Color next = (Color)GetValue(m_AssetNext, name);

        return Color.Lerp(last, next, m_TimeLerp);
    }

    void Start()
    {
        OnUseTimeline();
        UpdateShaderUniforms();
    }

    void OnEnable()
    {
    }

    void OnDisable()
    {
    }

#if UNITY_EDITOR
    private void OnDrawGizmosSelected() { OnValidate(); }
    private void OnValidate()
    {
        if (Application.isPlaying) return;
        Refresh();
    }
#endif

    void Refresh()
    {
        if (Application.isPlaying) return;

        UpdateAll();
    }

    void Update()
    {
        if (!Application.isPlaying) return;
        UpdateAll();
    }

    private void UpdateAll()
    {

        if(GetAsset() == null || m_SunTransform == null || m_MoonTransform == null || m_DomeTransform == null
            || m_CloudTransform == null || m_StarsTransform == null)
            return;
        
        if(m_UseTimeline && (m_AssetLast == null || m_AssetNext == null))
            return;

        UpdateShaderUniforms();
    }

    private void UpdateShaderUniforms()
    {
        if(GetAsset() == null)
            return;

        UpdateCelestials();

        if(m_PropertyBlock == null)
            m_PropertyBlock = new MaterialPropertyBlock();
        m_PropertyBlock.Clear();
      
        //
        m_PropertyBlock.SetFloat(Uniforms._RayleighMultiplier, m_UseTimeline ? GetFloatCurrent("RayleighMultiplier") : GetAsset().RayleighMultiplier);
        m_PropertyBlock.SetFloat(Uniforms._MieMultiplier, m_UseTimeline ? GetFloatCurrent("MieMultiplier") : GetAsset().MieMultiplier);
        // m_PropertyBlock.SetFloat(Uniforms._Directionality, m_UseTimeline ? GetFloatCurrent("Directionality") : GetAsset().Directionality);
        m_PropertyBlock.SetFloat(Uniforms._Contrast, m_UseTimeline ? GetFloatCurrent("Contrast") : GetAsset().Contrast);
        m_PropertyBlock.SetFloat(Uniforms._Brightness, m_UseTimeline ? GetFloatCurrent("Brightness") : GetAsset().Brightness);
        //
        m_PropertyBlock.SetColor(Uniforms._DaySkyColor, m_UseTimeline ? GetColorCurrent("DaySkyColor") : GetAsset().DaySkyColor);
        m_PropertyBlock.SetFloat(Uniforms._SunHaloSize, m_UseTimeline ? GetFloatCurrent("SunHaloSize") : GetAsset().SunHaloSize);
        m_PropertyBlock.SetColor(Uniforms._SunColor, m_UseTimeline ? GetColorCurrent("SunColor") : GetAsset().SunColor);
        m_PropertyBlock.SetFloat(Uniforms._SunSize, (m_UseTimeline ? GetFloatCurrent("SunSize") : GetAsset().SunSize));
        //
        m_PropertyBlock.SetColor(Uniforms._NightSkyColor, m_UseTimeline ? GetColorCurrent("NightSkyColor") : GetAsset().NightSkyColor);
        m_PropertyBlock.SetFloat(Uniforms._MoonHaloSize, m_UseTimeline ? GetFloatCurrent("MoonHaloSize") : GetAsset().MoonHaloSize);
        m_PropertyBlock.SetColor(Uniforms._MoonHaloColor, m_UseTimeline ? GetColorCurrent("MoonHaloColor") : GetAsset().MoonHaloColor/* * m_MoonAboveHorizon*/);
        m_PropertyBlock.SetColor(Uniforms._MoonColor, m_UseTimeline ? GetColorCurrent("MoonColor") : GetAsset().MoonColor);
        m_PropertyBlock.SetFloat(Uniforms._MoonSize, (m_UseTimeline ? GetFloatCurrent("MoonSize") : GetAsset().MoonSize) * 10f);
        //
        Color NightGroundColor = m_UseTimeline ? GetColorCurrent("NightGroundColor") : GetAsset().NightGroundColor;
        Color DayGroundColor = m_UseTimeline ? GetColorCurrent("DayGroundColor") : GetAsset().DayGroundColor;
        Color GroundColor = Color.Lerp(NightGroundColor, DayGroundColor, m_LerpValue);
        m_PropertyBlock.SetColor(Uniforms._GroundColor, GroundColor);
        //
        m_PropertyBlock.SetVector(Uniforms._LocalSunDirection, m_LocalSunDirection);
        m_PropertyBlock.SetVector(Uniforms._LocalMoonDirection, m_LocalMoonDirection);
        //
        if(m_MoonTexture != null)
            m_PropertyBlock.SetTexture(Uniforms._MoonTexture, m_MoonTexture);
        m_PropertyBlock.SetMatrix(Uniforms._WorldToMoonMatrix, m_MoonTransform.worldToLocalMatrix);

        //
        if(m_SkyRenderer == null)
            m_SkyRenderer = m_DomeTransform.GetComponent<MeshRenderer>();

        m_SkyRenderer.SetPropertyBlock(m_PropertyBlock);

        // ----------------------------------------------------------------------------
        UpdateCloud();

        float CloudSize = m_UseTimeline ? GetFloatCurrent("CloudSize") : GetAsset().CloudSize;
        m_PropertyBlock.SetVector(Uniforms._CloudSize, new Vector3(CloudSize * 4, CloudSize, CloudSize * 4));
        m_PropertyBlock.SetVector(Uniforms._CloudWind, m_CloudUV);
        m_PropertyBlock.SetColor(Uniforms._CloudNightColor, m_UseTimeline ? GetColorCurrent("CloudNightColor") : GetAsset().CloudNightColor);
        m_PropertyBlock.SetColor(Uniforms._CloudDayColor, m_UseTimeline ? GetColorCurrent("CloudDayColor") : GetAsset().CloudDayColor);
        m_PropertyBlock.SetFloat(Uniforms._CloudScattering, m_UseTimeline ? GetFloatCurrent("CloudScattering") : GetAsset().CloudScattering);
        m_PropertyBlock.SetFloat(Uniforms._CloudBrightness, m_UseTimeline ? GetFloatCurrent("CloudBrightness") : GetAsset().CloudBrightness);
        m_PropertyBlock.SetFloat(Uniforms._CloudColoring, m_UseTimeline ? GetFloatCurrent("CloudColoring") : GetAsset().CloudColoring);
        m_PropertyBlock.SetFloat(Uniforms._CloudSkyColorIntensity, m_UseTimeline ? GetFloatCurrent("CloudSkyColorIntensity") : GetAsset().CloudSkyColorIntensity);
        m_PropertyBlock.SetFloat(Uniforms._CloudOpacity,  m_UseTimeline ? GetFloatCurrent("CloudOpacity") : GetAsset().CloudOpacity);
        m_PropertyBlock.SetFloat(Uniforms._CloudCoverage, Mathf.Lerp(0.8f, 0.0f, m_UseTimeline ? GetFloatCurrent("CloudCoverage") : GetAsset().CloudCoverage));
        m_PropertyBlock.SetFloat(Uniforms._CloudDensity, Mathf.Lerp(0.0f, 10.0f, m_UseTimeline ? GetFloatCurrent("CloudDensity") : GetAsset().CloudDensity));
        m_PropertyBlock.SetFloat(Uniforms._CloudAttenuation, Mathf.Lerp(0.0f, 1.0f, m_UseTimeline ? GetFloatCurrent("CloudAttenuation") : GetAsset().CloudAttenuation));
        m_PropertyBlock.SetFloat(Uniforms._CloudSaturation, Mathf.Lerp(0.0f, 2.0f, m_UseTimeline ? GetFloatCurrent("CloudSaturation") : GetAsset().CloudSaturation));
        m_PropertyBlock.SetFloat(Uniforms._CloudClip, Mathf.Lerp(0.0f, 2.0f, m_UseTimeline ? GetFloatCurrent("CloudClip") : GetAsset().CloudClip));

        if(m_CloudTexture != null)
            m_PropertyBlock.SetTexture(Uniforms._CloudTexture, m_CloudTexture);

        if(m_CloudRenderer == null)
            m_CloudRenderer = m_CloudTransform.GetComponent<MeshRenderer>();

        m_CloudRenderer.SetPropertyBlock(m_PropertyBlock);

        // ----------------------------------------------------------------------------
        m_PropertyBlock.Clear();
        m_PropertyBlock.SetFloat(Uniforms._StarBrightness, (m_UseTimeline ? GetFloatCurrent("StarBrightness") : GetAsset().StarBrightness) * (1 - m_LerpValue));
        m_PropertyBlock.SetFloat(Uniforms._StarSize, m_UseTimeline ? GetFloatCurrent("StarSize") : GetAsset().StarSize);

        if(m_StarsRenderer == null)
            m_StarsRenderer = m_StarsTransform.GetComponent<MeshRenderer>();

        m_StarsRenderer.SetPropertyBlock(m_PropertyBlock);
    }

    void UpdateCloud()
	{
        float CloudWindDegrees = m_UseTimeline ? GetFloatCurrent("CloudWindDegrees") : GetAsset().CloudWindDegrees;
		float u = Mathf.Sin(Mathf.Deg2Rad * CloudWindDegrees);
		float v = Mathf.Cos(Mathf.Deg2Rad * CloudWindDegrees);

		float time = 1e-3f * Time.deltaTime;
		float wind = (m_UseTimeline ? GetFloatCurrent("CloudWindSpeed") : GetAsset().CloudWindSpeed) * time;

        if(m_CloudUV == null)
        {
            m_CloudUV = new Vector3(Random.value, Random.value, Random.value);
        }
		float x = m_CloudUV.x;
		float y = m_CloudUV.y;
		float z = m_CloudUV.z;

		y += time * 0.1f;
		x -= wind * u;
		z -= wind * v;

		x -= Mathf.Floor(x);
		y -= Mathf.Floor(y);
		z -= Mathf.Floor(z);

		m_CloudUV = new Vector3(x, y, z);
	}

	/// Convert spherical coordinates to cartesian coordinates.
	/// \param theta Spherical coordinates theta.
	/// \param phi Spherical coordinates phi.
	/// \return Unity position in local space.
	public Vector3 OrbitalToLocal(float theta, float phi)
	{
		Vector3 res;

		float sinTheta = Mathf.Sin(theta);
		float cosTheta = Mathf.Cos(theta);
		float sinPhi   = Mathf.Sin(phi);
		float cosPhi   = Mathf.Cos(phi);

		res.z = sinTheta * cosPhi;
		res.y = cosTheta;
		res.x = sinTheta * sinPhi;

		return res;
	}

    private void UpdateCelestials()
	{
        float Hour = m_UseTimeline ? GetFloatCurrent("Hour") : GetAsset().Hour;
        float SunZenith, SunAltitude, SunAzimuth, MoonZenith, MoonAltitude, MoonAzimuth;

		// Celestial computations
		float lst_rad, sun_zenith_rad, sun_altitude_rad, sun_azimuth_rad, moon_zenith_rad, moon_altitude_rad, moon_azimuth_rad;
		{
			// Local latitude
			float lat_rad = Mathf.Deg2Rad * m_Latitude;
			float lat_sin = Mathf.Sin(lat_rad);
			float lat_cos = Mathf.Cos(lat_rad);
			// Local longitude
			float lon_deg = m_Longitude;
			// Horizon angle
			float horizon_rad = 90f * Mathf.Deg2Rad;
			// Date
			int   year  = m_Year;
			int   month = m_Month;
			int   day   = m_Day;
			float hour  = Hour - m_UTC;

			// Time scale
			float d = 367 * year - 7 * (year + (month + 9) / 12) / 4 + 275 * month / 9 + day - 730530 + hour / 24f;
			float d_noon = 367 * year - 7 * (year + (month + 9) / 12) / 4 + 275 * month / 9 + day - 730530 + 12f / 24f;

			// Tilt of earth's axis of rotation
			float ecl = 23.4393f - 3.563E-7f * d;
			float ecl_rad = Mathf.Deg2Rad * ecl;
			float ecl_sin = Mathf.Sin(ecl_rad);
			float ecl_cos = Mathf.Cos(ecl_rad);

			// Sun position
			{
				// See http://www.stjarnhimlen.se/comp/ppcomp.html#4

				float w = 282.9404f + 4.70935E-5f * d;
				float e = 0.016709f - 1.151E-9f * d;
				float M = 356.0470f + 0.9856002585f * d;

				float M_rad = Mathf.Deg2Rad * M;
				float M_sin = Mathf.Sin(M_rad);
				float M_cos = Mathf.Cos(M_rad);

				// See http://www.stjarnhimlen.se/comp/ppcomp.html#5

				float E_rad = M_rad + e * M_sin * (1f + e * M_cos);
				float E_sin = Mathf.Sin(E_rad);
				float E_cos = Mathf.Cos(E_rad);

				float xv = E_cos - e;
				float yv = Mathf.Sqrt(1f - e*e) * E_sin;

				float v = Mathf.Rad2Deg * Mathf.Atan2(yv, xv);
				float r = Mathf.Sqrt(xv*xv + yv*yv);

				float l_deg = v + w;
				float l_rad = Mathf.Deg2Rad * l_deg;
				float l_sin = Mathf.Sin(l_rad);
				float l_cos = Mathf.Cos(l_rad);

				float xs = r * l_cos;
				float ys = r * l_sin;

				float xe = xs;
				float ye = ys * ecl_cos;
				float ze = ys * ecl_sin;

				float rasc_rad = Mathf.Atan2(ye, xe);
				float decl_rad = Mathf.Atan2(ze, Mathf.Sqrt(xe * xe + ye * ye));
				float decl_sin = Mathf.Sin(decl_rad);
				float decl_cos = Mathf.Cos(decl_rad);

				// See http://www.stjarnhimlen.se/comp/ppcomp.html#5b

				float Ls = v + w;

				float GMST0_deg = Ls + 180f;
				float GMST_deg  = GMST0_deg + 15f * hour;

				lst_rad = Mathf.Deg2Rad * (GMST_deg + lon_deg);

				// See http://www.stjarnhimlen.se/comp/ppcomp.html#12b

				float HA_rad = lst_rad - rasc_rad;
				float HA_sin = Mathf.Sin(HA_rad);
				float HA_cos = Mathf.Cos(HA_rad);

				float x = HA_cos * decl_cos;
				float y = HA_sin * decl_cos;
				float z = decl_sin;

				float xhor = x * lat_sin - z * lat_cos;
				float yhor = y;
				float zhor = x * lat_cos + z * lat_sin;

				float azimuth  = Mathf.Atan2(yhor, xhor) + Mathf.Deg2Rad * 180f;
				float altitude = Mathf.Atan2(zhor, Mathf.Sqrt(xhor * xhor + yhor * yhor));

				sun_zenith_rad   = horizon_rad - altitude;
				sun_altitude_rad = altitude;
				sun_azimuth_rad  = azimuth;
			}

			SunZenith   = Mathf.Rad2Deg * sun_zenith_rad;
			SunAltitude = Mathf.Rad2Deg * sun_altitude_rad;
			SunAzimuth  = Mathf.Rad2Deg * sun_azimuth_rad;

			// Moon position
            if (m_UseRealisticMoonPosition)
			{
				// See http://www.stjarnhimlen.se/comp/ppcomp.html#4

				float N = 125.1228f - 0.0529538083f * d;
				float i = 5.1454f;
				float w = 318.0634f + 0.1643573223f * d;
				float a = 60.2666f;
				float e = 0.054900f;
				float M = 115.3654f + 13.0649929509f * d;

				float N_rad = Mathf.Deg2Rad * N;
				float N_sin = Mathf.Sin(N_rad);
				float N_cos = Mathf.Cos(N_rad);

				float i_rad = Mathf.Deg2Rad * i;
				float i_sin = Mathf.Sin(i_rad);
				float i_cos = Mathf.Cos(i_rad);

				float M_rad = Mathf.Deg2Rad * M;
				float M_sin = Mathf.Sin(M_rad);
				float M_cos = Mathf.Cos(M_rad);

				// See http://www.stjarnhimlen.se/comp/ppcomp.html#6

				float E_rad = M_rad + e * M_sin * (1f + e * M_cos);
				float E_sin = Mathf.Sin(E_rad);
				float E_cos = Mathf.Cos(E_rad);

				float xv = a * (E_cos - e);
				float yv = a * (Mathf.Sqrt(1f - e*e) * E_sin);

				float v = Mathf.Rad2Deg * Mathf.Atan2(yv, xv);
				float r = Mathf.Sqrt(xv*xv + yv*yv);

				float l_deg = v + w;
				float l_rad = Mathf.Deg2Rad * l_deg;
				float l_sin = Mathf.Sin(l_rad);
				float l_cos = Mathf.Cos(l_rad);

				// See http://www.stjarnhimlen.se/comp/ppcomp.html#7

				float xh = r * (N_cos * l_cos - N_sin * l_sin * i_cos);
				float yh = r * (N_sin * l_cos + N_cos * l_sin * i_cos);
				float zh = r * (l_sin * i_sin);

				// See http://www.stjarnhimlen.se/comp/ppcomp.html#11

				float xg = xh;
				float yg = yh;
				float zg = zh;

				// See http://www.stjarnhimlen.se/comp/ppcomp.html#12

				float xe = xg;
				float ye = yg * ecl_cos - zg * ecl_sin;
				float ze = yg * ecl_sin + zg * ecl_cos;

				float rasc_rad = Mathf.Atan2(ye, xe);
				float decl_rad = Mathf.Atan2(ze, Mathf.Sqrt(xe * xe + ye * ye));
				float decl_sin = Mathf.Sin(decl_rad);
				float decl_cos = Mathf.Cos(decl_rad);

				// See http://www.stjarnhimlen.se/comp/ppcomp.html#12b

				float HA_rad = lst_rad - rasc_rad;
				float HA_sin = Mathf.Sin(HA_rad);
				float HA_cos = Mathf.Cos(HA_rad);

				float x = HA_cos * decl_cos;
				float y = HA_sin * decl_cos;
				float z = decl_sin;

				float xhor = x * lat_sin - z * lat_cos;
				float yhor = y;
				float zhor = x * lat_cos + z * lat_sin;

				float azimuth  = Mathf.Atan2(yhor, xhor) + Mathf.Deg2Rad * 180f;
				float altitude = Mathf.Atan2(zhor, Mathf.Sqrt(xhor * xhor + yhor * yhor));

				moon_zenith_rad   = horizon_rad - altitude;
				moon_altitude_rad = altitude;
				moon_azimuth_rad  = azimuth;
			}
            else
			{
				moon_zenith_rad   = sun_zenith_rad - Mathf.PI;
				moon_altitude_rad = sun_altitude_rad - Mathf.PI;
				moon_azimuth_rad  = sun_azimuth_rad;
			}

			MoonZenith   = Mathf.Rad2Deg * moon_zenith_rad;
			MoonAltitude = Mathf.Rad2Deg * moon_altitude_rad;
			MoonAzimuth  = Mathf.Rad2Deg * moon_azimuth_rad;
		}

		// Transform updates
		{
			Quaternion spaceRot = Quaternion.Euler(90 - m_Latitude, 0, 0) * Quaternion.Euler(0, 180 + lst_rad * Mathf.Rad2Deg, 0);

			var sunPos = OrbitalToLocal(sun_zenith_rad, sun_azimuth_rad);

            m_SunTransform.localPosition = sunPos;
            m_SunTransform.LookAt(m_DomeTransform.position, m_SunTransform.up);

			var moonPos = OrbitalToLocal(moon_zenith_rad, moon_azimuth_rad);

            var moonFwd = spaceRot * -Vector3.right;
            m_MoonTransform.localPosition = moonPos;
            m_MoonTransform.LookAt(m_DomeTransform.position, moonFwd);
		}

		// Color calculations
		{
			// Lerp value
			m_LerpValue = Mathf.InverseLerp(105f, 90f, SunZenith);

			// Constants
			const float falloffAngle  = 5.0f;
			m_MoonAboveHorizon = Mathf.Clamp01((90f - moon_zenith_rad * Mathf.Rad2Deg) / falloffAngle);
		}

		// Direction vectors
		{
			Vector3 SunDirection = - m_SunTransform.forward;
			m_LocalSunDirection = m_DomeTransform.InverseTransformDirection(SunDirection);

			Vector3 MoonDirection = - m_MoonTransform.forward;
			m_LocalMoonDirection = m_DomeTransform.InverseTransformDirection(MoonDirection);
		}
	}
}
