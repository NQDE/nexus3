property :role_name, String, name_property: true
property :description, String, default: ''.freeze
property :roles, Array, default: lazy { [] }
property :privileges, Array, default: lazy { [] }
property :api_endpoint, String, identity: true, default: lazy { node['nexus3']['api']['endpoint'] }
property :api_username, String, identity: true, default: lazy { node['nexus3']['api']['username'] }
property :api_password, String, identity: true, sensitive: true, default: lazy { node['nexus3']['api']['password'] }

load_current_value do
  begin
    res = ::Nexus3::Api.new(api_endpoint, api_username, api_password).run_script('get_role', role_name)
    config = JSON.parse(res)
    current_value_does_not_exist! if config.nil?
    ::Chef::Log.debug "Role config is #{config}"
    description config['description']
    roles config['roles']
    privileges config['privileges']
  rescue ::LoadError, ::Nexus3::ApiError => e
    ::Chef::Log.warn "A '#{e.class}' occurred: #{e.message}"
    current_value_does_not_exist!
  end
end

action :create do
  init

  converge_if_changed do
    nexus3_api "upsert_role #{new_resource.role_name}" do
      script_name 'upsert_role'
      args rolename: new_resource.role_name,
           description: new_resource.description,
           role_list: new_resource.roles,
           privilege_list: new_resource.privileges

      action %i(create run)
      endpoint new_resource.api_endpoint
      username new_resource.api_username
      password new_resource.api_password

      content ::Nexus3::Scripts.groovy_content('upsert_role', node)
    end
  end
end

action :delete do
  init

  converge_if_changed do
    nexus3_api "delete_role #{new_resource.role_name}" do
      script_name 'delete_role'
      args new_resource.role_name

      action %i(create run)
      endpoint new_resource.api_endpoint
      username new_resource.api_username
      password new_resource.api_password

      content ::Nexus3::Scripts.groovy_content('delete_role', node)
    end
  end
end

action_class do
  def init
    chef_gem 'httpclient' do
      compile_time true
    end

    nexus3_api 'get_role' do
      action :create
      endpoint new_resource.api_endpoint
      username new_resource.api_username
      password new_resource.api_password

      content ::Nexus3::Scripts.groovy_content('get_role', node)
    end
  end

  def whyrun_supported?
    true
  end
end
