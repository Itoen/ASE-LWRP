Shader /*ase_name*/ "Custom/LightWeightSimpleLighting" /*end*/
{
 Properties
 {
     /*ase_props*/
 }
 
 SubShader
 {
     Tags{ "RenderType" = "Opaque" "Queue"="Geometry" "RenderPipeline" = "LightweightPipeline"}
     Cull Back
     HLSLINCLUDE
     #pragma target 3.0
     ENDHLSL
     Pass
     {
         Tags{"LightMode" = "LightweightForward"}
         Name "Base"
         
         Blend One Zero
         ZWrite On
         ZTest LEqual
         Offset 0,0
         ColorMask RGBA
         /*ase_stencil*/
         HLSLPROGRAM
         // Required to compile gles 2.0 with standard srp library
         #pragma prefer_hlslcc gles
         #pragma exclude_renderers d3d11_9x

         // -------------------------------------
         // Lightweight Pipeline keywords
         #pragma multi_compile _ _ADDITIONAL_LIGHTS
         #pragma multi_compile _ _VERTEX_LIGHTS
         #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
         #pragma multi_compile _ _SHADOWS_ENABLED
         #pragma multi_compile _ _LOCAL_SHADOWS_ENABLED
         #pragma multi_compile _ _SHADOWS_SOFT
         #pragma multi_compile _ _SHADOWS_CASCADE

     
         #pragma vertex vert
         #pragma fragment frag
     
         /*ase_pragma*/

         // Lighting include is needed because of GI
         #include "LWRP/ShaderLibrary/Core.hlsl"
         #include "LWRP/ShaderLibrary/Lighting.hlsl"
         #include "CoreRP/ShaderLibrary/Color.hlsl"
         #include "LWRP/ShaderLibrary/InputSurfaceUnlit.hlsl"
         #include "ShaderGraphLibrary/Functions.hlsl"
         
         /*ase_globals*/
                 
         struct GraphVertexInput
         {
             float4 vertex : POSITION;
             float3 ase_normal : NORMAL;
             float4 ase_tangent : TANGENT;
             float4 texcoord1 : TEXCOORD1;
             /*ase_vdata:p=p;n=n;t=t;uv1=tc1.xyzw*/
             UNITY_VERTEX_INPUT_INSTANCE_ID
         };
 
         struct GraphVertexOutput
         {
             float4 clipPos                  : SV_POSITION;
             float4 shadowCoord              : TEXCOORD0;
             float4 tSpace0                  : TEXCOORD1;
             float4 tSpace1                  : TEXCOORD2;
             float4 tSpace2                  : TEXCOORD3;
             /*ase_interp(4,):sp=sp.xyzw;wn.x=tc1.z;wn.y=tc2.z;wn.z=tc3.z;wt.x=tc1.x;wt.y=tc2.x;wt.z=tc3.x;wbt.x=tc1.y;wbt.y=tc2.y;wbt.z=tc3.y;wp.x=tc1.w;wp.y=tc2.w;wp.z=tc3.w*/
             UNITY_VERTEX_INPUT_INSTANCE_ID
         };

         GraphVertexOutput vert (GraphVertexInput v/*ase_vert_input*/ )
         {
             GraphVertexOutput o = (GraphVertexOutput)0;
     
             UNITY_SETUP_INSTANCE_ID(v);
             UNITY_TRANSFER_INSTANCE_ID(v, o);
     
             /*ase_vert_code:v=GraphVertexInput;o=GraphVertexOutput*/
             v.vertex.xyz += /*ase_vert_out:Vertex Offset;Float3;8;-1;_Vertex*/ float3( 0, 0, 0 ) /*end*/;
             v.ase_normal = /*ase_vert_out:Vertex Normal;Float3;10;-1;_Normal*/ v.ase_normal /*end*/;

             float3 lwWNormal = TransformObjectToWorldNormal(v.ase_normal);
             float3 lwWorldPos = TransformObjectToWorld(v.vertex.xyz);
             float3 lwWTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
             float3 lwWBinormal = normalize(cross(lwWNormal, lwWTangent) * v.ase_tangent.w);
             o.tSpace0 = float4(lwWTangent.x, lwWBinormal.x, lwWNormal.x, lwWorldPos.x);
             o.tSpace1 = float4(lwWTangent.y, lwWBinormal.y, lwWNormal.y, lwWorldPos.y);
             o.tSpace2 = float4(lwWTangent.z, lwWBinormal.z, lwWNormal.z, lwWorldPos.z);

             o.clipPos = TransformWorldToHClip(TransformObjectToWorld(v.vertex.xyz));

             #ifdef _SHADOWS_ENABLED
             #if SHADOWS_SCREEN
                 o.shadowCoord = ComputeShadowCoord ( o.clipPos );
             #else
                 o.shadowCoord = TransformWorldToShadowCoord ( lwWorldPos );
             #endif
             #endif

             return o;
         }
     
         half4 frag (GraphVertexOutput IN /*ase_frag_input*/) : SV_Target
         {
             UNITY_SETUP_INSTANCE_ID(IN);
             /*ase_frag_code:IN=GraphVertexOutput*/
             float3 Diffuse = /*ase_frag_out:Diffuse;Float3;0*/0/*end*/;
             float3 Emission = /*ase_frag_out:Emission;Float3;3*/0/*end*/;
             float Alpha = /*ase_frag_out:Alpha;Float;1;-1;_Alpha*/1/*end*/;
             float AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;2;-1;_AlphaClip*/0/*end*/;

             float3 WorldSpaceNormal = normalize(float3(IN.tSpace0.z,IN.tSpace1.z,IN.tSpace2.z));
             float3 WorldSpacePosition = float3(IN.tSpace0.w,IN.tSpace1.w,IN.tSpace2.w);

     #if SHADER_HINT_NICE_QUALITY
             WorldSpaceNormal = normalize ( WorldSpaceNormal );
     #endif
             
             half attenuation = MainLightRealtimeShadowAttenuation(IN.shadowCoord);

     #ifdef _ADDITIONAL_LIGHTS
             int pixelLightCount = GetPixelLightCount();
             for (int i = 0; i < pixelLightCount; ++i)
             {
                Light light = GetLight(i, WorldSpacePosition);
                light.attenuation *= LocalLightRealtimeShadowAttenuation(light.index, WorldSpacePosition);
                attenuation *= light.attenuation;
             }
     #endif

             half3 finalColor = (Diffuse * attenuation) + Emission;

     #if _AlphaClip
             clip(Alpha - AlphaClipThreshold);
     #endif
             return half4(finalColor, Alpha);
         }
         ENDHLSL
     }

        UsePass "LightweightPipeline/Standard (Simple Lighting)/ShadowCaster"
     
     Pass
     {
         /*ase_hide_pass*/
         Name "DepthOnly"
         Tags{"LightMode" = "DepthOnly"}

         ZWrite On
         ColorMask 0
         
         HLSLPROGRAM
         #pragma prefer_hlslcc gles
    
         #pragma multi_compile_instancing

         #pragma vertex vert
         #pragma fragment frag

         #include "LWRP/ShaderLibrary/Core.hlsl"
         /*ase_pragma*/
         /*ase_globals*/

         struct GraphVertexInput
         {
             float4 vertex : POSITION;
             float4 ase_normal : NORMAL;
             /*ase_vdata:p=p;n=n*/
             UNITY_VERTEX_INPUT_INSTANCE_ID
         };

         struct GraphVertexOutput
         {
             float4 clipPos : SV_POSITION;
             /*ase_interp(0,):sp=sp.xyzw;*/
             UNITY_VERTEX_INPUT_INSTANCE_ID
         };

         GraphVertexOutput vert (GraphVertexInput v/*ase_vert_input*/)
         {
             GraphVertexOutput o;
             UNITY_SETUP_INSTANCE_ID(v);
             UNITY_TRANSFER_INSTANCE_ID(v, o);

             /*ase_vert_code:v=GraphVertexInput;o=GraphVertexOutput*/

             v.vertex.xyz += /*ase_vert_out:Vertex Offset;Float3;2;-1;_Vertex*/ float3(0,0,0) /*end*/;
             v.ase_normal = /*ase_vert_out:Vertex Normal;Float3;3;-1;_Normal*/ v.ase_normal /*end*/;
             o.clipPos = TransformObjectToHClip(v.vertex.xyz);
             return o;
         }

         half4 frag (GraphVertexOutput IN /*ase_frag_input*/) : SV_Target
         {
             UNITY_SETUP_INSTANCE_ID(IN);

             /*ase_frag_code:IN=GraphVertexOutput*/

             float Alpha = /*ase_frag_out:Alpha;Float;0;-1;_Alpha*/1/*end*/;
             float AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;1;-1;_AlphaClip*/AlphaClipThreshold/*end*/;
             
             #if _AlphaClip
                 clip(Alpha - AlphaClipThreshold);
             #endif
             return Alpha;
             return 0;
         }
         ENDHLSL
     }
 }   
 FallBack "Hidden/InternalErrorShader"
}
