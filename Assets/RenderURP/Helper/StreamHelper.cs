using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public static class StreamHelper
{
    static byte[] s_Buff = new byte[256];

    //BinaryWriter
    public static void WriteVector3(Stream stream, Vector3 v)
    {
        byte[] sBuff = BitConverter.GetBytes(v.x);
        stream.Write(sBuff, 0, sBuff.Length);
        sBuff = BitConverter.GetBytes(v.y);
        stream.Write(sBuff, 0, sBuff.Length);
        sBuff = BitConverter.GetBytes(v.z);
        stream.Write(sBuff, 0, sBuff.Length);
    }

    public static Vector3 ReadVector3(Stream stream)
    {
        Vector3 v = Vector3.zero;
        stream.Read(s_Buff, 0, sizeof(float));
        v.x = BitConverter.ToSingle(s_Buff, 0);
        stream.Read(s_Buff, 0, sizeof(float));
        v.y = BitConverter.ToSingle(s_Buff, 0);
        stream.Read(s_Buff, 0, sizeof(float));
        v.z = BitConverter.ToSingle(s_Buff, 0);
        return v;
    }

    public static void WriteVector4(Stream stream, Vector4 v)
    {
        byte[] sBuff = BitConverter.GetBytes(v.x);
        stream.Write(sBuff, 0, sBuff.Length);
        sBuff = BitConverter.GetBytes(v.y);
        stream.Write(sBuff, 0, sBuff.Length);
        sBuff = BitConverter.GetBytes(v.z);
        stream.Write(sBuff, 0, sBuff.Length);
        sBuff = BitConverter.GetBytes(v.w);
        stream.Write(sBuff, 0, sBuff.Length);
    }

    public static Vector4 ReadVector4(Stream stream)
    {
        Vector4 v = Vector4.zero;
        stream.Read(s_Buff, 0, sizeof(float));
        v.x = BitConverter.ToSingle(s_Buff, 0);
        stream.Read(s_Buff, 0, sizeof(float));
        v.y = BitConverter.ToSingle(s_Buff, 0);
        stream.Read(s_Buff, 0, sizeof(float));
        v.z = BitConverter.ToSingle(s_Buff, 0);
        stream.Read(s_Buff, 0, sizeof(float));
        v.w = BitConverter.ToSingle(s_Buff, 0);
        return v;
    }

    public static void WriteVector2(Stream stream, Vector2 v)
    {
        byte[] sBuff = BitConverter.GetBytes(v.x);
        stream.Write(sBuff, 0, sBuff.Length);
        sBuff = BitConverter.GetBytes(v.y);
        stream.Write(sBuff, 0, sBuff.Length);
    }

    public static Vector2 ReadVector2(Stream stream)
    {
        Vector2 v = Vector2.zero;
        stream.Read(s_Buff, 0, sizeof(float));
        v.x = BitConverter.ToSingle(s_Buff, 0);
        stream.Read(s_Buff, 0, sizeof(float));
        v.y = BitConverter.ToSingle(s_Buff, 0);
        return v;
    }

    public static void WriteFloat(Stream stream, float value)
    {
        byte[] sBuff = BitConverter.GetBytes(value);
        stream.Write(sBuff, 0, sizeof(float));
    }

    public static float ReadFloat(Stream stream)
    {
        float value = 0;
        stream.Read(s_Buff, 0, sizeof(float));
        value = BitConverter.ToSingle(s_Buff, 0);
        return value;
    }

    /// <summary>
    /// 用byte代替int来存储数据
    /// 范围0-255
    /// </summary>
    /// <param name="stream"></param>
    /// <param name="value"></param>
    public static void WriteByte(Stream stream, byte value)
    {
        byte[] sBuff = BitConverter.GetBytes(value);
        stream.Write(sBuff, 0, sizeof(byte));
    }

    public static int ReadByte(Stream stream, ref byte[] sBuff)
    {
        int value = 0;
        stream.Read(sBuff, 0, sizeof(byte));
        value = (byte) BitConverter.ToUInt16(sBuff, 0);
        return value;
    }


    public static void WriteShort(Stream stream, short value)
    {
        byte[] sBuff = BitConverter.GetBytes(value);
        stream.Write(sBuff, 0, sizeof(short));
    }

    public static int ReadShort(Stream stream)
    {
        short value = 0;
        stream.Read(s_Buff, 0, sizeof(short));
        value = BitConverter.ToInt16(s_Buff, 0);
        return value;
    }


    public static void WriteInt(Stream stream, int value)
    {
        byte[] sBuff = BitConverter.GetBytes(value);
        stream.Write(sBuff, 0, sizeof(int));
    }

    public static int ReadInt(Stream stream)
    {
        int value = 0;
        stream.Read(s_Buff, 0, sizeof(int));
        value = (int) BitConverter.ToUInt32(s_Buff, 0);
        return value;
    }
}
