###
# Used by shiv
# A very basic controller handler that allows restarting and reloading on the fly..

class ControllerHandler < RackWelder
  def initialize(log, cfg, roundhouse)
    @logger = log
    @REMOTE_IP_TAG = 'HTTP_X_FORWARDED_FOR'
    @cfg = cfg # cfg..

    setup_access_list(cfg['controller'])
    @roundhouse = roundhouse
  end

  def process(request, response)
    ip = request.env[@REMOTE_IP_TAG]
    ip = '0.0.0.0' unless ip

    unless allowed(ip)
      give_X(response, 403, 'text/plain', "Access from #{request.env[@REMOTE_IP_TAG]} is not allowed. Go Away.")
      return
    end
    action = request.env['PATH_INFO'].split('/').last
    @logger.msginfo("Controller: Recieved action '#{action}'")
    puts(@cfg['controller']['reload_action'])
    case (action)
    when @cfg['controller']['reload_action']
      reload(request, response)
    else
      give_X(response, 404, 'text/plain', "'#{request.env['PATH_INFO']}' is not a valid controller url..")
    end
  end

  private

  ##
  # Handles a reload request..
  def reload(_request, response)
    @roundhouse.load(@cfg)
    give_X(response, 200, 'text/plain', 'Reloading..')
  end

  ##
  # turns a string ip (xxx.xxx.xxx.xxx ) to a number set..
  def ip_to_nip(ip)
    nip = []
    ip.split('.').each { |x| nip << x.to_i }
    nip
  end

  ##
  # checks to see if a_ip == b_ip..
  def nip_test(a_ip, b_ip)
    0.upto(3) { |x| return false if (a_ip[x] != b_ip[x]) }
    true
  end

  ##
  # sets up the allowed ip list..
  def setup_access_list(_cfg)
    @access_list = []
    for ip in @cfg['controller']['ips_allowed']
      @access_list << ip_to_nip(ip)
    end
  end

  ##
  # checks to see if x is allowed..
  def allowed(ip)
    nip = ip_to_nip(ip)
    for x_ip in @access_list
      return true if nip_test(nip, x_ip)
    end
    false
  end
end
