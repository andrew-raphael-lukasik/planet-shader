Shader "Custom/Planet"
{
	Properties
	{
		_MainTex												("(Surface) Texture", 2D) = "white" {}
		[HDR] _Tint													("(Surface) Tint", Color) = (1.0, 1.0, 1.0, 1)
		//_LightMultiplier											("(Surface) Light Multiplier", Float) = 1
		[Toggle(SPECULAR_ON)] _SpecularEnabled							("(Surface) Specular Enabled", Float) = 0
			[HDR] _SpecColor													("(Surface) Specular Color", Color) = (1,1,1,1)
			_SpecPower													("(Surface) Specular Power", Range(0.01,1)) = 0.5
		[Toggle(RIM_ON)] _RimEnabled							("(Rim) Enabled", Float) = 0
			[HDR] _RimColor											("(Rim) Rim Color", Color) = (0.26,0.19,0.16,0.0)
			_RimPower												("(Rim) Rim Power", Range(0.5,8.0)) = 3.0

		[Toggle(ATMO_ON)] _AtmoEnabled							("(Atmosphere) Enabled", Float) = 0
	        [HDR] _AtmoColor												("(Atmosphere) Color", Color) = (0.5, 0.5, 1.0, 1)
	        _Size													("(Atmosphere) Size", Float) = 0.03
	        _Falloff												("(Atmosphere) Falloff", Float) = 1
	        _AtmosphereTransparency									("(Atmosphere) Transparency", Float) = 1.75
	        _LightInfluenceFactor									("(Atmosphere) Transparency Light Influence Factor", Float) = 0.1

        [Toggle(CLOUDS_ON)] _CloudsEnabled						("(Clouds) Enabled", Float) = 0
	        _CloudsTex												("(Clouds) Texture", 2D) = "black" {}
	        [HDR] _CloudsTint												("(Clouds) Tint", Color) = (0.5, 0.5, 1.0, 1)
	        _CloudsMaxDotProduct									("(Clouds) Max( Dot Product , this value )", Float) = 0.0
	        _CloudsTransparencyEdgesBrighten								("(Clouds) Transparency Edges Brightness", Float) = 0.0
	        [Toggle(CLOUDS_COLCORR)] _CloudsColorCorrection			("(Clouds) Color Correction Enabled", Float) = 0
		        [HDR] _CloudsGradientStart									("(Clouds) Color Correction Gradient Start", Color) = (0.0, 0.0, 0.0,0.0)
		        [HDR] _CloudsGradientEnd										("(Clouds) Color Correction Gradient End", Color) = (1.0, 1.0, 1.0, 1)
	        _CloudsFlowMap											("(Clouds) Flow Map", 2D) = "black" {}
			_CloudsFlowAmount										("(Clouds) Flow Amount", Float) = 0.5
			_CloudsFlowSpeed										("(Clouds) Flow Speed", Float) = 0.5
			_CloudsAltitude											("(Clouds) Altitude", Range(0.0,1)) = 0.0
			
	}



	// SURFACE:
	SubShader
	{
		
		Tags { "RenderType" = "Opaque" }
		CGPROGRAM
			#pragma surface surf BlinnPhong//Lambert

			#pragma shader_feature RIM_ON
			#pragma shader_feature SPECULAR_ON

			struct Input {
				half2 uv_MainTex;
				half3 viewDir;
			};

			sampler2D _MainTex;
			half _SpecPower;
			half3 _RimColor;
			half _RimPower;
			half3 _Tint;

			void surf( Input IN , inout SurfaceOutput o )
			{
				half4 tex = tex2D( _MainTex , IN.uv_MainTex );

				//albedo:
				o.Albedo = tex.rgb * _Tint;

				//specular:
				#if SPECULAR_ON
					o.Specular = _SpecPower;
					o.Gloss = tex.a;
				#endif

				//rim light:
				#if RIM_ON
					half rim = 1.0 - saturate( dot( normalize( IN.viewDir ) , o.Normal ) );
					o.Emission = _RimColor.rgb * pow( rim , _RimPower );
				#endif
			}
		ENDCG



		// ATMOSPHERE:
		Tags {"LightMode" = "ForwardBase" "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
        Pass
        {
            Name "ATMO"//"FORWARD"
            Cull Front
            Blend SrcAlpha One
			ZWrite Off
 
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #pragma shader_feature ATMO_ON
 
                #pragma fragmentoption ARB_fog_exp2
                #pragma fragmentoption ARB_precision_hint_fastest
 				
                #include "UnityCG.cginc"
                #include "Lighting.cginc"
 				
                uniform half4 _AtmoColor;
                uniform half _Size;
                uniform half _Falloff;
                uniform half _LightInfluenceFactor;
                uniform half _AtmosphereTransparency;
 				
                struct v2f
                {
                	half4 pos : SV_POSITION;

                	#if ATMO_ON
                    	half4 color : COLOR;
                    #endif
                };
 				
                v2f vert(appdata_base v)
                {
                    v2f o;

                    #if ATMO_ON
	                    v.vertex.xyz += v.normal*_Size;
	                    o.pos = UnityObjectToClipPos( v.vertex );

	                    half3 normal = mul( (half3x3)unity_ObjectToWorld , v.normal );
	                    half3 worldvertpos = mul( unity_ObjectToWorld , v.vertex );
	                    normal = normalize( normal );
	                    half3 viewDir = normalize( worldvertpos - _WorldSpaceCameraPos );
	                    half dotViewDir = dot( viewDir , normal );
	                    half dotLightDir = dot( normal , _WorldSpaceLightPos0 );

	                    half alpha1 = dotViewDir * _AtmosphereTransparency + dotLightDir * _LightInfluenceFactor;
						alpha1 = saturate( alpha1 );
						alpha1 = pow( alpha1 , _Falloff );
						half alpha2 = dotViewDir * dotLightDir * 2.0;
						alpha2 = saturate( alpha2 );
						alpha2 = pow( alpha2 , _Falloff );

	                    half4 color = lerp(
	                    					_AtmoColor ,
	                    					_LightColor0 + _AtmoColor * _LightColor0 * 0.33 ,
	                    					saturate( alpha2 / ( alpha1 + alpha2 ) )
						);
						color.a = alpha1;
						o.color = color;
					#else
						o.pos = half4(0,0,0,0);
					#endif

                    return o;
                }
 				
                half4 frag(v2f i) : COLOR
                {
                	#if ATMO_ON
                    	return i.color;
                    #else
                    	return half4(0,0,0,0);
                	#endif
                }
            ENDCG
        }
        //#endif



        // CLOUDS:
        Tags { "LightMode" = "ForwardBase" "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
        Pass
        {
            Name "CLOUDS"
            //Cull Off
            Blend SrcAlpha One
            Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
 			
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #pragma shader_feature CLOUDS_ON
                #pragma shader_feature CLOUDS_COLCORR

                #pragma fragmentoption ARB_fog_exp2
                #pragma fragmentoption ARB_precision_hint_fastest
 				
                #include "UnityCG.cginc"
                #include "Lighting.cginc"

                struct appdata
				{
					half4 vertex : POSITION;

					#if CLOUDS_ON
						half3 normal : NORMAL;
						half2 texcoord : TEXCOORD0;
						fixed4 color : COLOR;
					#endif
				};

				struct v2f
				{
					half4 vertex : SV_POSITION;

					#if CLOUDS_ON
						half2 uv : TEXCOORD0;
						//UNITY_FOG_COORDS(1)
						fixed4 color : COLOR;
					#endif
				};

				sampler2D _CloudsTex; half4 _CloudsTex_ST;
				sampler2D _CloudsFlowMap;
				half _CloudsFlowAmount;
				half _CloudsFlowSpeed;
				half _CloudsAltitude;
				half _CloudsTransparencyEdgesBrighten;
				half _CloudsMaxDotProduct;
				half4 _CloudsTint;
				half4 _CloudsGradientStart;
				half4 _CloudsGradientEnd;

				half _Size;

				v2f vert (appdata v)
				{
					v2f o;

					#if CLOUDS_ON
						o.vertex = UnityObjectToClipPos( v.vertex );

						v.vertex.xyz += v.normal*_Size*_CloudsAltitude;
		                o.vertex = UnityObjectToClipPos( v.vertex );

						o.uv = TRANSFORM_TEX( v.texcoord , _CloudsTex );

						//UNITY_TRANSFER_FOG( o , o.vertex );

						fixed4 vcol = v.color;

						half3 normal = mul( (half3x3)unity_ObjectToWorld , v.normal );
	                    half3 worldvertpos = mul( unity_ObjectToWorld , v.vertex );
	                    normal = normalize( normal );
	                    half3 viewDir = normalize( worldvertpos - _WorldSpaceCameraPos );
	                    half dotLightDir = dot( normal , _WorldSpaceLightPos0 );

	                    vcol.rgb = vcol.rgb * 0.1 + vcol.rgb * max( dotLightDir , -0.3 );
						o.color = vcol;
					#else
						o.vertex = half4(0,0,0,0);
					#endif

					return o;
				}
				
				half4 frag (v2f i) : SV_Target
				{
					#if CLOUDS_ON
						half2 uv = i.uv;
		                half time = _Time[1];

		                half2 flowRaw = tex2D( _CloudsFlowMap , uv ).rg;
						half2 flow = ( flowRaw * 2.0 - 1.0 ) * _CloudsFlowAmount;

		                half phase0 = frac( time * _CloudsFlowSpeed);
		                half phase1 = frac( time * _CloudsFlowSpeed + 0.5 );
		 				
		                half4 tex0 = tex2D( _CloudsTex , uv + flow * phase0 );
		                half4 tex1 = tex2D( _CloudsTex , uv + flow * phase1 );
		 				
		                half lerpPhases = abs( (0.5 - phase0) / 0.5 );
		                half4 col = lerp( tex0 , tex1 , lerpPhases );

		                #if CLOUDS_COLCORR
							half colBrightness = col.r * 0.3 + col.g * 0.59 + col.b * 0.11;
							half4 correction = lerp( _CloudsGradientStart , _CloudsGradientEnd , colBrightness );//colBrightness );
							col = correction;
						#endif

		                half4 result = col * i.color * _CloudsTint;
		                half h = ( 1.0 - result.a ) * _CloudsTransparencyEdgesBrighten;
		                #if CLOUDS_COLCORR
		                	h *= colBrightness;
		                #endif
		                result.rgb += half3( h , h , h );
		                return max( result , half4(_CloudsMaxDotProduct,_CloudsMaxDotProduct,_CloudsMaxDotProduct,0) );
	                #else
						return half4(0,0,0,0);
					#endif
				}
            ENDCG
        }


	}

    Fallback "Diffuse"
  }