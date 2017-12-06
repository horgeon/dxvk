#pragma once

#include <dxbc_module.h>
#include <dxvk_device.h>

#include "../util/sha1/sha1_util.h"

#include "d3d11_device_child.h"
#include "d3d11_interfaces.h"

namespace dxvk {
  
  class D3D11Device;
  
  /**
   * \brief Shader module
   * 
   * 
   */
  class D3D11ShaderModule {
    
  public:
    
    D3D11ShaderModule();
    D3D11ShaderModule(
      const void*   pShaderBytecode,
            size_t  BytecodeLength);
    ~D3D11ShaderModule();
    
  private:
    
    
    SpirvCodeBuffer m_code;
    
    Sha1Hash ComputeShaderHash(
      const void*   pShaderBytecode,
            size_t  BytecodeLength) const;
    
    std::string ConstructFileName(
      const Sha1Hash&         hash,
      const DxbcProgramType&  type) const;
    
  };
  
  
  /**
   * \brief Common shader interface
   * 
   * Implements methods for all D3D11*Shader
   * interfaces and stores the actual shader
   * module object.
   */
  template<typename Base>
  class D3D11Shader : public D3D11DeviceChild<Base> {
    
  public:
    
    D3D11Shader(D3D11Device* device, D3D11ShaderModule&& module)
    : m_device(device), m_module(std::move(module)) { }
    
    ~D3D11Shader() { }
    
    HRESULT QueryInterface(REFIID riid, void** ppvObject) final {
      COM_QUERY_IFACE(riid, ppvObject, IUnknown);
      COM_QUERY_IFACE(riid, ppvObject, ID3D11DeviceChild);
      COM_QUERY_IFACE(riid, ppvObject, Base);
      
      Logger::warn("D3D11Shader::QueryInterface: Unknown interface query");
      return E_NOINTERFACE;
    }
    
    void GetDevice(ID3D11Device **ppDevice) final {
      *ppDevice = ref(m_device);
    }
    
    const D3D11ShaderModule& GetShaderModule() const {
      return m_module;
    }
    
  private:
    
    D3D11Device* const m_device;
    D3D11ShaderModule  m_module;
    
  };
  
  using D3D11VertexShader   = D3D11Shader<ID3D11VertexShader>;
  using D3D11HullShader     = D3D11Shader<ID3D11HullShader>;
  using D3D11DomainShader   = D3D11Shader<ID3D11DomainShader>;
  using D3D11GeometryShader = D3D11Shader<ID3D11GeometryShader>;
  using D3D11PixelShader    = D3D11Shader<ID3D11PixelShader>;
  using D3D11ComputeShader  = D3D11Shader<ID3D11ComputeShader>;
  
}
