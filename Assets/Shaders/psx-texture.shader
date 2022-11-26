Shader "psx/texture" {
	Properties {
		_MainTex("Base (RGB)", 2D) = "white" {}
		[MaterialToggle] _AffineMapping("Affine Mapping", float) = 1
		[MaterialToggle] _ScreenspaceVertexPrecision("Screen Space Vertex Snapping", float) = 0
		[ShowAsVector2] _VertexPrecision("Vertex Snapping Precision", Vector) = (0, 0, 0, 0)
	}
	
	SubShader {
		Tags { "RenderType" = "Opaque" }
		LOD 200

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
				};

				float4 _MainTex_ST;
				uniform half4 unity_FogStart;
				uniform half4 unity_FogEnd;

				vector _VertexPrecision;
			
				float _AffineMapping;		
				float _ScreenspaceVertexPrecision;		
	
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
					OUT.color = float4(ShadeVertexLightsFull(IN.vertex, IN.normal, 4, true), 1.0);
					OUT.color *= IN.color;

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

					//Fog
					float4 fogColor = unity_FogColor;

					float fogDensity = (unity_FogEnd - distance) / (unity_FogEnd - unity_FogStart);
					OUT.normal.g = fogDensity;
					OUT.normal.b = 1;

					OUT.colorFog = fogColor;
					OUT.colorFog.a = clamp(fogDensity,0,1);

					//Cut out polygons
					// if (distance > unity_FogStart.z + unity_FogColor.a * 255)
					// {
					// 	o.pos.w = 0;
					// }

					return OUT;
				}

				sampler2D _MainTex;

				float4 frag(v2f IN) : COLOR
				{
					half4 color = tex2D(_MainTex, _AffineMapping ? IN.uv_MainTex / IN.normal.r : IN.uv_MainTex);
					color *= IN.color; // shading

					// TODO: use fog alpha to limit fog opacity
					color *= IN.colorFog.a; // fog
					
					color.rgb += IN.colorFog.rgb*(1 - IN.colorFog.a);
					return color;
				}
			ENDCG 
		}
	}
}