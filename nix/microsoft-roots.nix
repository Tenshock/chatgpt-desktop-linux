{ fetchurl }:

{
  root2010 = fetchurl {
    url = "https://www.microsoft.com/pki/certs/MicRooCerAut_2010-06-23.crt";
    hash = "sha256-31Rb+RmiQ5w2mDtUzfyQPfpPN9OZbY2EtMMe7G88Fj4=";
  };

  root2011 = fetchurl {
    url = "https://www.microsoft.com/pki/certs/MicRooCerAut2011_2011_03_22.crt";
    hash = "sha256-hH32p4SXlD8n/HLrk/mmNzIKArVh0KkbCeh6eAftfGE=";
  };
}
