require "active_support/core_ext/object/try"
require "active_support/core_ext/hash/slice"

module ActionDispatch::Routing
  # Extended ActionDispatch::Routing::Mapper implementation to add routing method of ActivityNotification.
  class Mapper
    include ActivityNotification::PolymorphicHelpers

    # Includes notify_to method for routes, which is responsible to generate all necessary routes for notifications of activity_notification.
    #
    # When you have an User model configured as a target (e.g. defined acts_as_target),
    # you can create as follows in your routes:
    #   notify_to :users
    # This method creates the needed routes:
    #   # Notification routes
    #     user_notifications          GET    /users/:user_id/notifications(.:format)
    #       { controller:"activity_notification/notifications", action:"index", target_type:"users" }
    #     user_notification           GET    /users/:user_id/notifications/:id(.:format)
    #       { controller:"activity_notification/notifications", action:"show", target_type:"users" }
    #     user_notification           DELETE /users/:user_id/notifications/:id(.:format)
    #       { controller:"activity_notification/notifications", action:"destroy", target_type:"users" }
    #     open_all_user_notifications POST   /users/:user_id/notifications/open_all(.:format)
    #       { controller:"activity_notification/notifications", action:"open_all", target_type:"users" }
    #     move_user_notification      GET    /users/:user_id/notifications/:id/move(.:format)
    #       { controller:"activity_notification/notifications", action:"move", target_type:"users" }
    #     open_user_notification      POST   /users/:user_id/notifications/:id/open(.:format)
    #       { controller:"activity_notification/notifications", action:"open", target_type:"users" }
    #
    # When you use devise authentication and you want make notification targets assciated with devise,
    # you can create as follows in your routes:
    #   notify_to :users, with_devise: :users
    # This with_devise option creates the needed routes assciated with devise authentication:
    #   # Notification with devise routes
    #     user_notifications          GET    /users/:user_id/notifications(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"index", target_type:"users", devise_type:"users" }
    #     user_notification           GET    /users/:user_id/notifications/:id(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"show", target_type:"users", devise_type:"users" }
    #     user_notification           DELETE /users/:user_id/notifications/:id(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"destroy", target_type:"users", devise_type:"users" }
    #     open_all_user_notifications POST   /users/:user_id/notifications/open_all(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"open_all", target_type:"users", devise_type:"users" }
    #     move_user_notification      GET    /users/:user_id/notifications/:id/move(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"move", target_type:"users", devise_type:"users" }
    #     open_user_notification      POST   /users/:user_id/notifications/:id/open(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"open", target_type:"users", devise_type:"users" }
    #
    # When you would like to define subscription management paths with notification paths,
    # you can create as follows in your routes:
    #   notify_to :users, with_subscription: true
    # or you can also set options for subscription path:
    #   notify_to :users, with_subscription: { except: [:index] }
    # If you configure this :with_subscription option with :with_devise option, with_subscription paths are also automatically configured with devise authentication as the same as notifications
    #   notify_to :users, with_devise: :users, with_subscription: true
    #
    # @example Define notify_to in config/routes.rb
    #   notify_to :users
    # @example Define notify_to with options
    #   notify_to :users, only: [:open, :open_all, :move]
    # @example Integrated with Devise authentication
    #   notify_to :users, with_devise: :users
    # @example Define notification paths including subscription paths
    #   notify_to :users, with_subscription: true
    #
    # @overload notify_to(*resources, *options)
    #   @param          [Symbol]       resources Resources to notify
    #   @option options [Symbol]       :with_devise       (false)          Devise resources name for devise integration. Devise integration will be enabled by this option.
    #   @option options [Hash|Boolean] :with_subscription (false)          Subscription path options to define subscription management paths with notification paths. Calls subscribed_by routing when truthy value is passed as this option.
    #   @option options [String]       :model             (:notifications) Model name of notifications
    #   @option options [String]       :controller        ("activity_notification/notifications" | activity_notification/notifications_with_devise") :controller option as resources routing
    #   @option options [Symbol]       :as                (nil)            :as option as resources routing
    #   @option options [Array]        :only              (nil)            :only option as resources routing
    #   @option options [Array]        :except            (nil)            :except option as resources routing
    # @return [ActionDispatch::Routing::Mapper] Routing mapper instance
    def notify_to(*resources)
      options = create_options(:notifications, resources.extract_options!, [:new, :create, :edit, :update])

      resources.each do |target|
        self.resources target, only: :none do
          options[:defaults] = { target_type: target.to_s }.merge(options[:devise_defaults])
          resources_options = options.select { |key, _| [:with_devise, :with_subscription, :subscription_option, :model, :devise_defaults].exclude? key }
          self.resources options[:model], resources_options do
            collection do
              post :open_all unless ignore_path?(:open_all, options)
            end
            member do
              get  :move     unless ignore_path?(:move, options)
              post :open     unless ignore_path?(:open, options)
            end
          end
        end

        if options[:with_subscription].present? && target.to_s.to_model_class.subscription_enabled?
          subscribed_by target, options[:subscription_option]
        end
      end

      self
    end

    # Includes subscribed_by method for routes, which is responsible to generate all necessary routes for subscriptions of activity_notification.
    #
    # When you have an User model configured as a target (e.g. defined acts_as_target),
    # you can create as follows in your routes:
    #   subscribed_by :users
    # This method creates the needed routes:
    #   # Subscription routes
    #     user_subscriptions                                GET    /users/:user_id/subscriptions(.:format)
    #       { controller:"activity_notification/subscriptions", action:"index", target_type:"users" }
    #     user_subscription                                 GET    /users/:user_id/subscriptions/:id(.:format)
    #       { controller:"activity_notification/subscriptions", action:"show", target_type:"users" }
    #     open_all_user_subscriptions                       POST   /users/:user_id/subscriptions(.:format)
    #       { controller:"activity_notification/subscriptions", action:"create", target_type:"users" }
    #     user_subscription                                 DELETE /users/:user_id/subscriptions/:id(.:format)
    #       { controller:"activity_notification/subscriptions", action:"destroy", target_type:"users" }
    #     subscribe_user_subscription                       POST   /users/:user_id/subscriptions/:id/subscribe(.:format)
    #       { controller:"activity_notification/subscriptions", action:"subscribe", target_type:"users" }
    #     unsubscribe_user_subscription                     POST   /users/:user_id/subscriptions/:id/unsubscribe(.:format)
    #       { controller:"activity_notification/subscriptions", action:"unsubscribe", target_type:"users" }
    #     subscribe_to_email_user_subscription              POST   /users/:user_id/subscriptions/:id/subscribe_to_email(.:format)
    #       { controller:"activity_notification/subscriptions", action:"subscribe_to_email", target_type:"users" }
    #     unsubscribe_to_email_user_subscription            POST   /users/:user_id/subscriptions/:id/unsubscribe_to_email(.:format)
    #       { controller:"activity_notification/subscriptions", action:"unsubscribe_to_email", target_type:"users" }
    #     subscribe_to_optional_target_user_subscription    POST   /users/:user_id/subscriptions/:id/subscribe_to_optional_target(.:format)
    #       { controller:"activity_notification/subscriptions", action:"subscribe_to_optional_target", target_type:"users" }
    #     unsubscribe_to_optional_target_user_subscription  POST   /users/:user_id/subscriptions/:id/unsubscribe_to_optional_target(.:format)
    #       { controller:"activity_notification/subscriptions", action:"unsubscribe_to_optional_target", target_type:"users" }
    #
    # When you use devise authentication and you want make subscription targets assciated with devise,
    # you can create as follows in your routes:
    #   notify_to :users, with_devise: :users
    # This with_devise option creates the needed routes assciated with devise authentication:
    #   # Subscription with devise routes
    #     user_subscriptions                                GET    /users/:user_id/subscriptions(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"index", target_type:"users", devise_type:"users" }
    #     user_subscription                                 GET    /users/:user_id/subscriptions/:id(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"show", target_type:"users", devise_type:"users" }
    #     open_all_user_subscriptions                       POST   /users/:user_id/subscriptions(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"create", target_type:"users", devise_type:"users" }
    #     user_subscription                                 DELETE /users/:user_id/subscriptions/:id(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"destroy", target_type:"users", devise_type:"users" }
    #     subscribe_user_subscription                       POST   /users/:user_id/subscriptions/:id/subscribe(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"subscribe", target_type:"users", devise_type:"users" }
    #     unsubscribe_user_subscription                     POST   /users/:user_id/subscriptions/:id/unsubscribe(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"unsubscribe", target_type:"users", devise_type:"users" }
    #     subscribe_to_email_user_subscription              POST   /users/:user_id/subscriptions/:id/subscribe_to_email(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"subscribe_to_email", target_type:"users", devise_type:"users" }
    #     unsubscribe_to_email_user_subscription            POST   /users/:user_id/subscriptions/:id/unsubscribe_to_email(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"unsubscribe_to_email", target_type:"users", devise_type:"users" }
    #     subscribe_to_optional_target_user_subscription    POST   /users/:user_id/subscriptions/:id/subscribe_to_optional_target(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"subscribe_to_optional_target", target_type:"users", devise_type:"users" }
    #     unsubscribe_to_optional_target_user_subscription  POST   /users/:user_id/subscriptions/:id/unsubscribe_to_optional_target(.:format)
    #       { controller:"activity_notification/subscriptions_with_devise", action:"unsubscribe_to_optional_target", target_type:"users", devise_type:"users" }
    #
    # @example Define subscribed_by in config/routes.rb
    #   subscribed_by :users
    # @example Define subscribed_by with options
    #   subscribed_by :users, except: [:index, :show]
    # @example Integrated with Devise authentication
    #   subscribed_by :users, with_devise: :users
    #
    # @overload subscribed_by(*resources, *options)
    #   @param          [Symbol]       resources Resources to notify
    #   @option options [Symbol]       :with_devise (false)          Devise resources name for devise integration. Devise integration will be enabled by this option.
    #   @option options [String]       :model       (:subscriptions) Model name of subscriptions
    #   @option options [String]       :controller  ("activity_notification/subscriptions" | activity_notification/subscriptions_with_devise") :controller option as resources routing
    #   @option options [Symbol]       :as          (nil)            :as option as resources routing
    #   @option options [Array]        :only        (nil)            :only option as resources routing
    #   @option options [Array]        :except      (nil)            :except option as resources routing
    # @return [ActionDispatch::Routing::Mapper] Routing mapper instance
    def subscribed_by(*resources)
      options = create_options(:subscriptions, resources.extract_options!, [:new, :edit, :update])

      resources.each do |target|
        self.resources target, only: :none do
          options[:defaults] = { target_type: target.to_s }.merge(options[:devise_defaults])
          resources_options = options.select { |key, _| [:with_devise, :model, :devise_defaults].exclude? key }
          self.resources options[:model], resources_options do
            member do
              post :subscribe                      unless ignore_path?(:subscribe, options)
              post :unsubscribe                    unless ignore_path?(:unsubscribe, options)
              post :subscribe_to_email             unless ignore_path?(:subscribe_to_email, options)
              post :unsubscribe_to_email           unless ignore_path?(:unsubscribe_to_email, options)
              post :subscribe_to_optional_target   unless ignore_path?(:subscribe_to_optional_target, options)
              post :unsubscribe_to_optional_target unless ignore_path?(:unsubscribe_to_optional_target, options)
            end
          end
        end
      end

      self
    end


    private

      # Check whether action path is ignored by :except or :only options
      # @api private
      # @return [Boolean] Whether action path is ignored
      def ignore_path?(action, options)
        options[:except].present? &&  options[:except].include?(action) and return true
        options[:only].present?   && !options[:only].include?(action)   and return true
        false
      end

      # Create options fo routing
      # @api private
      # @todo Check resources if it includes target module
      # @todo Check devise configuration in model
      # @todo Support other options like :as, :path_prefix, :path_names ...
      #
      # @param [Symbol] resource Name of the resource model
      # @return [Boolean] Whether action path is ignored
      def create_options(resource, options = {}, except_actions = [])
        # Check resources if it includes target module
        resources_name = resource.to_s.pluralize.underscore
        options[:model] ||= resources_name.to_sym
        if options[:with_devise].present?
          options[:controller] ||= "activity_notification/#{resources_name}_with_devise"
          options[:as]         ||= resources_name
          # Check devise configuration in model
          options[:devise_defaults] = { devise_type: options[:with_devise].to_s }
        else
          options[:controller] ||= "activity_notification/#{resources_name}"
          options[:devise_defaults] = {}
        end
        (options[:except] ||= []).concat(except_actions)
        if options[:with_subscription].present?
          options[:subscription_option] = (options[:with_subscription].is_a?(Hash) ? options[:with_subscription] : {})
                                            .merge(with_devise: options[:with_devise])
        end
        # Support other options like :as, :path_prefix, :path_names ...
        options
      end

  end
end
