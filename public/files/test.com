#require 'uri'

# Only supports the Git currently.
# Identifier: the remote name 
# url: the remote repository url
# scm: the remote repository type
class SyncScm < ActiveRecord::Base
  unloadable

  belongs_to :repository
  
  GIT_BIN = Redmine::Configuration['scm_git_command'] || "git"
  
  def remote_url_changed(old_url, url, scm_dir)  
    #scm_dir = repository.root_url
    id = self.class.get_identifier(old_url) if old_url != ''
    git_remote_rm(id, scm_dir) if old_url != ''
    id = identifier
    git_remote_add(id, url, scm_dir) if url != ''
    git_push(id, scm_dir)
  end

  def git_push(name, git_dir)
    if git_dir =~ %r{^\.*\/}
      #cfg = ScmConfig[repository.scm_name]
    
      cmd = 'GIT_SSL_NO_VERIFY=true '+ GIT_BIN
      cmd += ' --git-dir=' + git_dir + ' push ' + name
      RAILS_DEFAULT_LOGGER.error "Repository cmd failed: #{cmd}" unless system(cmd)
    else
      RAILS_DEFAULT_LOGGER.error "git remote push failed: no such git dir #{git_dir}"
    end
  end
  

  #async_method :remote_url_changed, :queue => 'file_serve.repo'
  #async_method :git_push, :queue => 'file_serve.repo'
  
  def before_destroy() 
    id = identifier
    scm_dir = repository.root_url
    git_remote_rm(id, scm_dir) if id != ''
  end
  
  def after_create()
    scm = 'Git'
  end
  
  def before_save()
    # only Git supports currently.
    scm = 'Git' if scm != 'Git'
  end

  def after_save()
    p "scm dir"
    scm_dir = repository.root_url
    p scm_dir
    case repository.scm_name
      when 'Git'
        if remote_user_changed? || remote_token_changed?
          p " usr change "
          git_set_github_user(remote_user, remote_token, scm_dir)
        end
        if url_changed? and url != url_was
          remote_url_changed(url_was, url, scm_dir)
        end
    end # Case
  end

  def git_set_github_user(user, token, git_dir)
    if user && token
      cmd = GIT_BIN
      cmd += ' --git-dir=' + git_dir + ' config github.'
      _cmd = cmd  + "user #{user}"
      p "lanuch cmd == ", _cmd
      RAILS_DEFAULT_LOGGER.error "Repository cmd failed: #{_cmd}" unless system(_cmd)
      _cmd = cmd  + "token #{token}"
      RAILS_DEFAULT_LOGGER.error "Repository cmd failed: #{_cmd}" unless system(_cmd)
    end
  end

  def git_remote_rm(name, git_dir)
    if git_dir =~ %r{^\.*\/}
      #cfg = ScmConfig[repository.scm_name]
    
      cmd = GIT_BIN
      cmd += ' --git-dir=' + git_dir + ' remote rm ' + name
      RAILS_DEFAULT_LOGGER.error "Repository cmd failed: #{cmd}" unless system(cmd)
    else
      RAILS_DEFAULT_LOGGER.error "git remote rm failed: no such git dir #{git_dir}"
    end
  end
  
  def git_remote_add(name, url, git_dir)
    if git_dir =~ %r{^\.*\/}
      #cfg = ScmConfig[repository.scm_name]
    
      cmd = GIT_BIN
      cmd += ' --git-dir=' + git_dir
      _cmd = cmd  + " remote add #{name} #{url}"
      RAILS_DEFAULT_LOGGER.error "Repository cmd failed: #{_cmd}" unless system(_cmd)
      _cmd = cmd  + " config --add remote.#{name}.push '+refs/heads/*:refs/heads/*'"
      RAILS_DEFAULT_LOGGER.error "Repository cmd failed: #{_cmd}" unless system(_cmd)
      _cmd = cmd  + " config --add remote.#{name}.push '+refs/tags/*:refs/tags/*'"
      RAILS_DEFAULT_LOGGER.error "Repository cmd failed: #{_cmd}" unless system(_cmd)
    else
      RAILS_DEFAULT_LOGGER.error "git remote add failed: no such git dir #{git_dir}"
    end
  end
  
  def self.get_identifier(url)
    url ||= '' 
    result = url.gsub('^(git|https?)\:\/\/', '')
    result = result.gsub('^\/*', '')
    result
  end
  
  def identifier
    self.class.get_identifier(url)
  end
  
  def push
    case  repository.scm_name
      when 'Git'
        git_push(identifier, repository.root_url)
    end
  end
  
  def clear_error
    last_error = ''
  end
  
  # drPush=1, drPull=2
  def execute
    if direction == 1
      push
    else
      pull
    end if last_error == ''
  end
end
