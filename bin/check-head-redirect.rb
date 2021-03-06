#! /usr/bin/env ruby
#
#   check-head-redirect
#
# DESCRIPTION:
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Leon Gibat <brendan.gibat@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
require 'sensu-plugin/check/cli'
require 'net/https'
require 'time'
require 'aws-sdk-core'
require 'json'
require 'sensu-plugins-http'

#
# Checks that redirection links can be followed in a set number of requests.
#
class CheckLastModified < Sensu::Plugin::Check::CLI
  include Common
  option :aws_access_key,
         short:       '-a AWS_ACCESS_KEY',
         long:        '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default:     ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short:       '-k AWS_SECRET_KEY',
         long:        '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default:     ENV['AWS_SECRET_KEY']

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :s3_config_bucket,
         short:       '-s S3_CONFIG_FILE',
         long:        '--s3-config-file S3_CONFIG_FILE',
         description: 'S3 config bucket'

  option :s3_config_key,
         short:       '-k S3_CONFIG_KEY',
         long:        '--s3-config-KEY S3_CONFIG_KEY',
         description: 'S3 config key'

  option :url,
          short: '-u URL',
          long: '--url URL',
          description: 'The URL of the file to be checked'

  option :user,
          short: '-U USER',
          long: '--username USER',
          description: 'A username to connect as'

  option :password,
          short: '-a PASS',
          long: '--password PASS',
          description: 'A password to use for the username'

  option :follow_redirects,
          short: '-r FOLLOW_REDIRECTS',
          long: '--redirect FOLLOW_REDIRECTS',
          proc: proc(&:to_i),
          default: 0,
          description: 'Follow first <N> redirects'

  option :follow_redirects_with_get,
          short: '-g GET_REDIRECTS',
          long: '--get-redirects GET_REDIRECTS',
          proc: proc(&:to_i),
          default: 0,
          description: 'Follow first <N> redirects with GET requests'

  def follow_uri(uri, total_redirects, get_redirects)
    location = URI(uri)
    http = Net::HTTP.new(location.host, location.port)
    if get_redirects > 0
      request = Net::HTTP::Get.new(location.request_uri)
    else
      request = Net::HTTP::Head.new(location.request_uri)
    end

    if config[:user] and config[:password] and total_redirects == config[:follow_redirects]
      http.use_ssl = true
      request.basic_auth(config[:user], config[:password])
    end

    response = http.request(request)
    if total_redirects > 0
      case response
      when Net::HTTPSuccess     then ok
      when Net::HTTPRedirection then follow_uri(response['location'], total_redirects - 1, get_redirects - 1)
      else
        critical 'Http Error'
      end
    else
      case response
      when Net::HTTPSuccess     then ok
      else
        critical 'Http Error'
      end
    end
  end

  def run

    aws_config
    merge_s3_config

    url = config[:url]

    #Validate arguments
    if not url
      unknown "No URL specified"
    end

    follow_uri(url, config[:follow_redirects], config[:follow_redirects_with_get])

  end
end
