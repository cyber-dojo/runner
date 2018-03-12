require_relative 'all_avatars_names'

module ValidAvatarName # mix-in

  module_function

  def valid_avatar_name?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  include AllAvatarsNames

end
