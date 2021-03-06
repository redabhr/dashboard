class ApplicationController < ActionController::Base
  include LocaleHelper
  include ApplicationHelper

  include SeamlessDatabasePool::ControllerFilter
  use_database_pool :all => :master

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # this is needed to avoid devise breaking on email param
  before_filter :configure_permitted_parameters, if: :devise_controller?
  before_filter :verify_params_before_cancan_loads_model

  around_filter :with_locale

  before_action :fix_crawlers_with_bad_accept_headers
  def fix_crawlers_with_bad_accept_headers
    # append text/html as an acceptable response type for Edmodo and weebly-agent's malformed HTTP_ACCEPT header.

    if request.formats.include?("image/*") &&
        (request.user_agent.include?("Edmodo") || request.user_agent.include?("weebly-agent"))
      request.formats.append Mime::HTML
    end
  end

  def reset_session_endpoint
    reset_session
    render text: "OK"
  end

# we need the following to fix a problem with the interaction between CanCan and strong_parameters
# https://github.com/ryanb/cancan/issues/835
  def verify_params_before_cancan_loads_model
    resource = controller_name.singularize.to_sym
    method = "#{resource}_params"
    params[resource] &&= send(method) if respond_to?(method, true)
  end

  def code_org_root_path
    Rails.env.production? ? "http://www.code.org" : Rails.env.development? ? "http://localhost:3000" : "http://staging.code.org"
  end

  # when CanCan denies access, send a 403 Forbidden response instead of causing a server error
  rescue_from CanCan::AccessDenied do
    head :forbidden
    # TODO if users are actually seeing this (eg. because they cleared
    # cookies and clicked on something), maybe we should render an
    # actual page
  end

  protected

  PERMITTED_USER_FIELDS = [:name, :username, :email, :password, :password_confirmation, :locale, :gender, :login,
      :remember_me, :birthday, :school, :full_address, :user_type]

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:account_update) do |u| u.permit PERMITTED_USER_FIELDS end
    devise_parameter_sanitizer.for(:sign_up) do |u| u.permit PERMITTED_USER_FIELDS end
    devise_parameter_sanitizer.for(:sign_in) do |u| u.permit PERMITTED_USER_FIELDS end
  end

  def with_locale
    I18n.with_locale(locale) do
      yield
    end
  end

  def milestone_response(options)
    response = {}
    script_level = options[:script_level]
    level = script_level.level
    script = script_level.script
    # figure out the previous level
    previous_level = script_level.previous_level
    if previous_level
      response[:previous_level] = build_script_level_path(previous_level)
    end

    # if they solved it, figure out next level
    if options[:solved?]
      response[:total_lines] = options[:total_lines]

      trophy_updates = options.fetch(:trophy_updates, [])
      if trophy_updates.length > 0
        response[:trophy_updates] = trophy_updates
      end

      next_level = script_level.next_level
      # If this is the end of the current script
      if !next_level
        # If the current script is hour of code, continue on to twenty-hour
        if script_level.script.hoc?
          next_level = Script.twenty_hour_script.get_script_level_by_chapter(script_level.chapter + 1)
          redirect = current_user ? build_script_level_path(next_level) : "http://code.org/api/hour/finish"
        else
          response[:redirect] = root_path
        end
        # Get the wrap up video
        video = script_level.script.wrapup_video
        if video
          video_info_response = video_info(video)
          video_info_response[:redirect] = redirect
          response[:video_info] = video_info_response
        end
        response[:message] = 'no more levels'
      end
      # Get the next_level setup
      if next_level
        response[:redirect] = build_script_level_path(next_level)

        if (level.game_id != next_level.level.game_id)
          response[:stage_changing] = {
              previous: { number: level.game_id, name: data_t_suffix('script.name', script.name, level.game.name) },
              new: { number: next_level.level.game_id, name: data_t_suffix('script.name', script.name, next_level.level.game.name) }
          }
        end

        if (level.skin != next_level.level.skin)
          response[:skin_changing] = { previous: level.skin, new: next_level.level.skin }
        end
      end
    else
      response[:message] = 'try again'
    end

    if options[:level_source]
      response[:level_source] = level_source_url(options[:level_source])
    end

    # logged in users can save solved levels to a gallery (subject to
    # additional logic in the blockly code because blockly owns
    # which levels are worth saving)
    if current_user && options[:level_source] && options[:solved?] && options[:activity]
      response[:save_to_gallery_url] = gallery_activities_path(gallery_activity: {activity_id: options[:activity].id})
    end

    # Check if the current level_source has program specific hint, use it if use is set.
    if ActivityHint.is_experimenting_feedback? && options[:level_source]
      experiment_hints = []
      options[:level_source].level_source_hints.each do |hint|
        if hint.selected?
          # Selected hint overwrites other hints
          response[:hint] = hint
          break
        elsif hint.experiment?
          experiment_hints.push(hint)
        end
      end
      # Randomly select one of the experimental hints
      if response[:hint].nil? && experiment_hints.length > 0
        response[:hint] = experiment_hints[rand(experiment_hints.count)]
      end

      # Record this activity
      if response[:hint]
        if options[:activity]
          ActivityHint.create!(
              activity_id: options[:activity].id,
              level_source_hint_id: response[:hint].id
          )
        end
        response[:hint] = response[:hint].hint
      end
    end

    # Set up hint design experiment
    if ExperimentActivity.is_experimenting_feedback_design? && options[:activity]
      response[:design] = ExperimentActivity.get_feedback_design(options[:activity].id)
    end

    response
  end

  def current_user
    if Rails.configuration.minimal_mode
      nil
    else
      super
    end
  end

  def nonminimal
    if Rails.configuration.minimal_mode
      render 'shared/overloaded', status: 502, formats: [:html]
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    code_org_root_path
  end

  def set_locale_cookie(locale)
    cookies[:language_] = { value: locale, domain: :all }
  end
end
