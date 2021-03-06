require 'rubygems'
require 'require_relative'
require 'net/http'
require 'open-uri'

require_relative '../lib/plist_generator.rb'
require_relative '../lib/ftp_upload.rb'
require_relative '../lib/ipa_search.rb'
require_relative '../lib/mail_parser.rb'
require_relative '../lib/mailer.rb'

class OtabuilderWrapper<Jenkins::Tasks::Publisher
  
  include Jenkins::Model::DescribableNative
  
  display_name 'Upload Build and Mail OTA link'
  
  attr_accessor :ipa_path
  attr_accessor :icon_path
  attr_accessor :bundle_identifier
  attr_accessor :bundle_version
  attr_accessor :title
  attr_accessor :ftp_ota_dir
  attr_accessor :ftp_host
  attr_accessor :ftp_user
  attr_accessor :ftp_password
  attr_accessor :gmail_user
  attr_accessor :gmail_pass
  attr_accessor :reciever_mail_id
  attr_accessor :http_translation
  attr_accessor :mail_body
  attr_accessor :mail_subject
  attr_accessor :reply_to
  attr_accessor :bcc
  
  def initialize(attrs)
    @ipa_path = attrs['ipa_path']
    @icon_path = attrs['icon_path']
    @bundle_identifier = attrs['bundle_identifier']
    @bundle_version = attrs['bundle_version']
    @title = attrs['title']
    @ftp_ota_dir = attrs['ftp_ota_dir']
    @ftp_host = attrs['ftp_host']
    @ftp_user = attrs['ftp_user']
    @ftp_password = attrs['ftp_password']
    @reciever_mail_id = attrs['reciever_mail_id']
    @http_translation = attrs['http_translation']
    @mail_subject = attrs['mail_subject']
    @reply_to = attrs['reply_to']
    @mail_body  = attrs['mail_body']
    @bcc = attrs['bcc']
    
  end
  
  def needsToRunAfterFinalized
    return true
  end
  
  def prebuild(build,listner)
  end
  

  def perform(build,launcher,listner)
      
      #project informations
      workspace_path = build.native.getProject.getWorkspace() #get the workspace path
      ipa_file = IPASearch::find_in "#{workspace_path}/#{@ipa_path}"
      icon_file = "#{workspace_path}/#{@icon_path}"
      ipa_filename = File.basename ipa_file
      icon_filename = File.basename icon_file
      
      #build informations
      project = build.native.getProject.displayName
      build_number = build.native.getNumber()
      build_number = build_number.to_s
      
      ipa_url = "#{@http_translation}#{@ftp_ota_dir}#{project}/#{build_number}/#{ipa_filename}"
      icon_url =  "#{@http_translation}#{@ftp_ota_dir}#{project}/#{build_number}/#{icon_filename}" 
      manifest_file = Manifest::create ipa_url,icon_url,@bundle_identifier,@bundle_version,@title,File.dirname(ipa_file)
     
      #begin
        FTP::upload @ftp_host, @ftp_user, @ftp_password, @ftp_ota_dir, project,build_number,[ipa_file,manifest_file,icon_file] 
      #rescue
       # listner.error "FTP Connection Refused, check the FTP Settings"
       # build.halt
       #end
      
      #Test this part is working 
      
      #If above works, delete the following parts
      
      manifest_filename = File.basename manifest_file
      itms_link = "itms-services://?action=download-manifest&url=#{@http_translation}#{@ftp_ota_dir}#{project}/#{build_number}/#{manifest_filename}"
      itms_link = itms_link.gsub /\s*/,''
      
      listner.info itms_link  
      mail_body = @mail_body
      mail_body = MailParser::substitute_variables mail_body do
        [
          {
            :replace=>"{itms_link}",
            :with=>itms_link
          },
          {
            :replace=>"{build_number}",
            :with=>build_number
          },
          {
            :replace=>"{project}",
            :with=>project
          }
        ]
      end

      mail_body = MailParser::get_html mail_body
      
      mail_subject = MailParser::substitute_variables @mail_subject do
        [
          {
            :replace=>"{build_number}",
            :with=>build_number
          },
          {
            :replace=>"{project}",
            :with=>project
          }
        ]
      end
      

      mail = JenkinsMail.new
      
      mail.compose do 
        {
          :to =>  @reciever_mail_id,
          :from => @sender_mail_id,
          :subject =>  mail_subject,
          :html_body=> mail_body,
          :reply_to=> @reply_to,
          :bcc=> @bcc
        }
      end

      mail.send
  end
        
end
