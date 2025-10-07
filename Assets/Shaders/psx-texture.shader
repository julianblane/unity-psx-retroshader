
Shader "psx/texture" {
	Properties {
		_MainTex("Base (RGB)", 2D) = "white" {}
		_Color ("Main Color", COLOR) = (1,1,1,1)
		[MaterialToggle] _AffineMapping("Affine Mapping", float) = 1
		_Fog("Fog", float) = 1
		[MaterialToggle] _ScreenspaceVertexPrecision("Screen Space Vertex Snapping", float) = 0
		[ShowAsVector2] _VertexPrecision("Vertex Snapping Precision", Vector) = (0, 0, 0, 0)
		[HDR] _HighlightColor ("Highlight", COLOR) = (0,0,0,0)
		_HighlightMinimum("Highlight Minimum", float) = 0
		_HighlightFrequency("Cycle Frequency", Float) = 0
	}
	
	SubShader {
		Tags { }
		LOD 200
		Blend SrcAlpha OneMinusSrcAlpha
		 
		Pass {
			Lighting On
			
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"

				struct v2f
				{
					fixed4 position : SV_POSITION;
					float2 uv_MainTex : TEXCOORD0; // UV coords for texture
				
					half4 color : COLOR0;
					half4 colorFog : COLOR1;
					half3 normal : TEXCOORD1;

					float3 worldNormal : TEXCOORD2;  // new
					float3 worldPos : TEXCOORD3;     // new
				};

				float4 _MainTex_ST;
				uniform half4 unity_FogStart;
				uniform half4 unity_FogEnd;

				vector _VertexPrecision;
			
				float _AffineMapping;
				float _Fog;
				float _ScreenspaceVertexPrecision;

				fixed4 _HighlightColor;
				float _HighlightMinimum;
				float _HighlightFrequency;
	
				v2f vert(appdata_full IN)
				{
					v2f OUT;

					// Vertex snapping
					float4 snapToPixel = UnityObjectToClipPos(IN.vertex);
					float4 vertex = snapToPixel;
					if(_ScreenspaceVertexPrecision)
					{
						vertex.xyz = snapToPixel.xyz / snapToPixel.w;
					}
					if (_VertexPrecision.x > 0)
					{
						vertex.x = floor(_VertexPrecision.x * vertex.x) / _VertexPrecision.x;
					}
					if (_VertexPrecision.y > 0)
					{
						vertex.y = floor(_VertexPrecision.y * vertex.y) / _VertexPrecision.y;
					}
					if (_VertexPrecision.w > 0){
						vertex.w = floor(_VertexPrecision.w * vertex.w) / _VertexPrecision.w;
					}
					if(_ScreenspaceVertexPrecision)
					{
						vertex.xyz *= snapToPixel.w;
					}
					OUT.position = vertex;

					// Vertex lighting 
				//	o.color =  float4(ShadeVertexLights(v.vertex, v.normal), 1.0);
					OUT.color = float4(ShadeVertexLightsFull(IN.vertex, IN.normal, 8, true), 1.0);
					OUT.color *= IN.color;

					OUT.worldNormal = UnityObjectToWorldNormal(IN.normal);
					OUT.worldPos = mul(unity_ObjectToWorld, IN.vertex).xyz;

					float distance = length(mul(UNITY_MATRIX_MV,IN.vertex));
					
					// Affine Texture Mapping
					if(_AffineMapping)
					{
						OUT.uv_MainTex = TRANSFORM_TEX(IN.texcoord, _MainTex);
						OUT.uv_MainTex *= distance + (vertex.w*(UNITY_LIGHTMODEL_AMBIENT.a * 8)) / distance / 2;
						OUT.normal = distance + (vertex.w*(UNITY_LIGHTMODEL_AMBIENT.a * 8)) / distance / 2;
					}
					else
					{
						OUT.uv_MainTex = IN.texcoord;
					}

					// Fog
					float fogDensity = (unity_FogEnd - distance) / (unity_FogEnd - unity_FogStart) / _Fog;
					OUT.normal.g = fogDensity;
					OUT.normal.b = 1;

					OUT.colorFog = unity_FogColor;
					// clamp max fog density to fog alpha channel
					OUT.colorFog.a = clamp(fogDensity, 1-unity_FogColor.a, 1);

					// Cut out polygons
					// if (distance > unity_FogStart.z + unity_FogColor.a * 255)
					// {
					// 	o.pos.w = 0;
					// }

					return OUT;
				}

				sampler2D _MainTex;
				fixed4 _Color;

				float4 frag(v2f IN) : COLOR
				{
					half4 color = tex2D(_MainTex, float4((_AffineMapping ? IN.uv_MainTex / IN.normal.r : IN.uv_MainTex) * _MainTex_ST, 0, 0));
					color *= IN.color; // shading
					color *= _Color; // tinting

					// Directional Highlight based on view direction
					float3 viewDir = normalize(_WorldSpaceCameraPos - IN.worldPos);
					float highlightStrength = saturate(dot(IN.worldNormal, viewDir));

					// Cycle highlight alpha
					float cycle = 1;
					if (_HighlightFrequency)
						cycle = sin(_Time.y * (2 * UNITY_PI * _HighlightFrequency)) * (1 - _HighlightMinimum) * 0.5 + 0.5 + (_HighlightMinimum / 2);

	                float4 highlight = _HighlightColor;
	                highlight.a = cycle;
					
					// highlightStrength = pow(highlightStrength, 4.0); // intensity
					color.rgb += color.rgb * highlight.rgb * highlight.a * highlightStrength;
					
					// fog
					if(_Fog)
					{
						color.rgb *= IN.colorFog.a; // darkening
						color.rgb += IN.colorFog.rgb * (1 - IN.colorFog.a); // tint
					}
					
					return color;
				}
			ENDCG 
		}
	}
} 