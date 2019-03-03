Shader /*ase_name*/ "Custom/LightWeightSimpleLighting" /*end*/
{
    Properties
    {
     /*ase_props*/
    }


    SubShader
    {
         Tags
         {
             "RenderPipeline" = "LightweightPipeline"
             "RenderType"="Opaque"
             "Queue"="Geometry" 
         }

         Cull Back
         HLSLINCLUDE
         #pragma target 3.0
         ENDHLSL
         /*ase_pass*/
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
             #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
             #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
             #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
             #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
             #pragma multi_compile _ _SHADOWS_SOFT
             #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            
             // -------------------------------------
             // Unity defined keywords
             #pragma multi_compile _ DIRLIGHTMAP_COMBINED
             #pragma multi_compile _ LIGHTMAP_ON
             #pragma multi_compile_fog

             //--------------------------------------
             // GPU Instancing
             #pragma multi_compile_instancing

             #pragma vertex vert
             #pragma fragment frag

             /*ase_pragma*/

             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"
             #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
             #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/ShaderGraphFunctions.hlsl"

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

             /*ase_funcs*/

             GraphVertexOutput vert (GraphVertexInput v/*ase_vert_input*/)
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

                 Light mainLight = GetMainLight(IN.shadowCoord);
                 half attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;

         #ifdef _ADDITIONAL_LIGHTS
                 int pixelLightCount = GetAdditionalLightsCount();
                 for (int i = 0; i < pixelLightCount; ++i)
                 {
                    Light light = GetAdditionalLight(i, WorldSpacePosition);
                    attenuation *= (light.distanceAttenuation * light.shadowAttenuation);
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

         /*ase_pass*/
         Pass
         {
             /*ase_hide_pass*/
             Name "ShadowCaster"
                Tags{"LightMode" = "ShadowCaster"}

             ZWrite On
             ZTest LEqual

             HLSLPROGRAM
             // Required to compile gles 2.0 with standard srp library
             #pragma prefer_hlslcc gles
             #pragma exclude_renderers d3d11_9x
            

             //--------------------------------------
             // GPU Instancing
             #pragma multi_compile_instancing

             #pragma vertex ShadowPassVertex
             #pragma fragment ShadowPassFragment

             /*ase_pragma*/

             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/ShaderGraphFunctions.hlsl"
             #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

             struct GraphVertexInput
             {
                 float4 vertex : POSITION;
                 float3 ase_normal : NORMAL;
                 /*ase_vdata:p=p;n=n*/
                 UNITY_VERTEX_INPUT_INSTANCE_ID
             };

             /*ase_globals*/

             struct VertexOutput
             {
                 float4 clipPos      : SV_POSITION;
                 /*ase_interp(7,):sp=sp*/
                 UNITY_VERTEX_INPUT_INSTANCE_ID
             };

             /*ase_funcs*/

             // x: global clip space bias, y: normal world space bias
             float4 _ShadowBias;
             float3 _LightDirection;

             VertexOutput ShadowPassVertex(GraphVertexInput v/*ase_vert_input*/)
             {
                 VertexOutput o;
                 UNITY_SETUP_INSTANCE_ID(v);
                 UNITY_TRANSFER_INSTANCE_ID(v, o);

                 /*ase_vert_code:v=GraphVertexInput;o=GraphVertexOutput*/
                 float3 vertexValue = /*ase_vert_out:Vertex Offset;Float3;2;-1;_Vertex*/ float3(0,0,0) /*end*/;
                 #ifdef ASE_ABSOLUTE_VERTEX_POS
                 v.vertex.xyz = vertexValue;
                 #else
                 v.vertex.xyz += vertexValue;
                 #endif

                 v.ase_normal = /*ase_vert_out:Vertex Normal;Float3;3;-1;_Normal*/ v.ase_normal /*end*/;

                 float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                 float3 normalWS = TransformObjectToWorldDir(v.ase_normal);

                 float invNdotL = 1.0 - saturate(dot(_LightDirection, normalWS));
                 float scale = invNdotL * _ShadowBias.y;

                 positionWS = _LightDirection * _ShadowBias.xxx + positionWS;
                 positionWS = normalWS * scale.xxx + positionWS;
                 float4 clipPos = TransformWorldToHClip(positionWS);

             #if UNITY_REVERSED_Z
                 clipPos.z = min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
             #else
                 clipPos.z = max(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
             #endif
                 o.clipPos = clipPos;

                 return o;
             }

             half4 ShadowPassFragment(VertexOutput IN/*ase_frag_input*/) : SV_TARGET
             {
                 UNITY_SETUP_INSTANCE_ID(IN);

                 /*ase_frag_code:IN=GraphVertexOutput*/

                 float Alpha = /*ase_frag_out:Alpha;Float;0;-1;_Alpha*/1/*end*/;
                 float AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;1;-1;_AlphaClip*/AlphaClipThreshold/*end*/;

             #if _AlphaClip
                 clip(Alpha - AlphaClipThreshold);
            #endif
                 return 0;
             }
             ENDHLSL
         }

         /*ase_pass*/
         Pass
         {
             /*ase_hide_pass*/
             Name "DepthOnly"
             Tags{"LightMode" = "DepthOnly"}

             ZWrite On
             ColorMask 0

             HLSLPROGRAM
             // Required to compile gles 2.0 with standard srp library
             #pragma prefer_hlslcc gles
             #pragma exclude_renderers d3d11_9x

             //--------------------------------------
             // GPU Instancing
             #pragma multi_compile_instancing

             #pragma vertex vert
             #pragma fragment frag

             /*ase_pragma*/

             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/ShaderGraphFunctions.hlsl"
             #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

             /*ase_globals*/

             struct GraphVertexInput
             {
                 float4 vertex : POSITION;
                 float3 ase_normal : NORMAL;
                 /*ase_vdata:p=p;n=n*/
                 UNITY_VERTEX_INPUT_INSTANCE_ID
             };

             struct VertexOutput
             {
                 float4 clipPos      : SV_POSITION;
                 /*ase_interp(0,):sp=sp*/
                 UNITY_VERTEX_INPUT_INSTANCE_ID
                 UNITY_VERTEX_OUTPUT_STEREO
             };

             /*ase_funcs*/
               

             VertexOutput vert(GraphVertexInput v/*ase_vert_input*/)
             {
                 VertexOutput o = (VertexOutput)0;
                 UNITY_SETUP_INSTANCE_ID(v);
                 UNITY_TRANSFER_INSTANCE_ID(v, o);
                 UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                 /*ase_vert_code:v=GraphVertexInput;o=GraphVertexOutput*/
                 float3 vertexValue = /*ase_vert_out:Vertex Offset;Float3;2;-1;_Vertex*/ float3(0,0,0) /*end*/;
                 #ifdef ASE_ABSOLUTE_VERTEX_POS
                 v.vertex.xyz = vertexValue;
                 #else
                 v.vertex.xyz += vertexValue;
                 #endif

                 v.ase_normal = /*ase_vert_out:Vertex Normal;Float3;3;-1;_Normal*/ v.ase_normal /*end*/;

                 o.clipPos = TransformObjectToHClip(v.vertex.xyz);
                 return o;
             }

             half4 frag(VertexOutput IN/*ase_frag_input*/) : SV_TARGET
             {
                 UNITY_SETUP_INSTANCE_ID(IN);

                 /*ase_frag_code:IN=GraphVertexOutput*/

                 float Alpha = /*ase_frag_out:Alpha;Float;0;-1;_Alpha*/1/*end*/;
                 float AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;1;-1;_AlphaClip*/AlphaClipThreshold/*end*/;

             #if _AlphaClip
                 clip(Alpha - AlphaClipThreshold);
            #endif
                 return 0;
             }
             ENDHLSL
         }

         /*ase_pass*/
         Pass
         {
             /*ase_hide_pass*/
             Name "Meta"
             Tags{"LightMode" = "Meta"}

             Cull Off

             HLSLPROGRAM
             // Required to compile gles 2.0 with standard srp library
             #pragma prefer_hlslcc gles
             #pragma exclude_renderers d3d11_9x

             #pragma vertex vert
             #pragma fragment frag

             /*ase_pragma*/

             uniform float4 _MainTex_ST;
             
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/MetaInput.hlsl"
             #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/ShaderGraphFunctions.hlsl"
             #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

             /*ase_globals*/

             #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
             #pragma shader_feature EDITOR_VISUALIZATION


             struct GraphVertexInput
             {
                 float4 vertex : POSITION;
                 float3 ase_normal : NORMAL;
                 float4 texcoord1 : TEXCOORD1;
                 float4 texcoord2 : TEXCOORD2;
                 /*ase_vdata:p=p;n=n;uv1=tc1;uv2=tc2*/
                 UNITY_VERTEX_INPUT_INSTANCE_ID
             };

             struct VertexOutput
             {
                 float4 clipPos      : SV_POSITION;
                 /*ase_interp(0,):sp=sp;uv1=tc1*/
                 UNITY_VERTEX_INPUT_INSTANCE_ID
                 UNITY_VERTEX_OUTPUT_STEREO
             };

            /*ase_funcs*/

            VertexOutput vert(GraphVertexInput v/*ase_vert_input*/)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                /*ase_vert_code:v=GraphVertexInput;o=GraphVertexOutput*/

                float3 vertexValue = /*ase_vert_out:Vertex Offset;Float3;4;-1;_Vertex*/ float3(0,0,0) /*end*/;
                #ifdef ASE_ABSOLUTE_VERTEX_POS
                v.vertex.xyz = vertexValue;
                #else
                v.vertex.xyz += vertexValue;
                #endif

                v.ase_normal = /*ase_vert_out:Vertex Normal;Float3;5;-1;_Normal*/ v.ase_normal /*end*/;
             
                o.clipPos = MetaVertexPosition(v.vertex, v.texcoord1.xy, v.texcoord2.xy, unity_LightmapST);
                return o;
            }

            half4 frag(VertexOutput IN/*ase_frag_input*/) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);

                /*ase_frag_code:IN=GraphVertexOutput*/
             
                float3 Albedo = /*ase_frag_out:Albedo;Float3;0;-1;_Albedo*/float3(0.5, 0.5, 0.5)/*end*/;
                float3 Emission = /*ase_frag_out:Emission;Float3;1;-1;_Emission*/0/*end*/;
                float Alpha = /*ase_frag_out:Alpha;Float;2;-1;_Alpha*/1/*end*/;
                float AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;3;-1;_AlphaClip*/0/*end*/;

             #if _AlphaClip
                clip(Alpha - AlphaClipThreshold);
            #endif

                MetaInput metaInput = (MetaInput)0;
                metaInput.Albedo = Albedo;
                metaInput.Emission = Emission;
                
                return MetaFragment(metaInput);
            }
            ENDHLSL
        }
     /*ase_pass_end*/
    }
    FallBack "Hidden/InternalErrorShader"
    CustomEditor "ASEMaterialInspector"
}
