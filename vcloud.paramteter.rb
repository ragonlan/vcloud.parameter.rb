require 'facter'

def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each { |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    }
  end
  return nil
end

vmcmd  = which('vmtoolsd')

if vmcmd
  Facter.debug "vmtoolsd found in #{vmcmd}"
  ovfEnv = Facter::Util::Resolution.exec("#{vmcmd} --cmd 'info-get guestinfo.ovfEnv'")
else
  Facter.debug "vmtoolsd not found or vmware tools not instaled."
end

if ovfEnv
  config =  Hash.new
  begin
    require 'xmlsimple'
  rescue Exception=>e
    Facter.warn "Error loading xmlsimple library: #{e}"
    #exit(0)
  end
  begin
    config = XmlSimple.xml_in(ovfEnv, { 'KeyAttr' => 'oe:key', 'ForceArray' => false})
  rescue => error
    Facter.debug "Error parsing XML ovfEnv or no evfEnv defined."
    #exit(0)
  end
    
  Facter.add(:vcloudId) do
    #default for non-vmware nodes
    setcode do
      nil
    end
  end
  
  Facter.add(:vcloudid) do
    confine :virtual => :vmware
    #VMWare, but not linux
    setcode do
      'vCenterId-unknown'
    end
  end
  
  Facter.add(:vcloudid) do
    confine :virtual => :vmware
    confine :kernel => :linux
    #vmware and linux. whee!
    setcode do
      if config.key?('ve:vCenterId')
        config['ve:vCenterId']
      else
        nil
      end
    end
  end
  if config.key?('PropertySection') and config['PropertySection'].key?('Property')
    config['PropertySection']['Property'].each do |k, v|
        Facter.add("vcloud_prop_#{k}") do
          confine :virtual => :vmware
          confine :kernel => :linux
          setcode do
            v["oe:value"]
          end
        end
    end
  end
end
