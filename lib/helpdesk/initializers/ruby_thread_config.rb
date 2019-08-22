class ThreadError::AbortOnExceptionSet < StandardError
end

############################################################
# Thread.abort_on_exception property when set to true,     #
#    and an unhandled exception is raised                  #
#   from a child thread, initiates a ruby VM shutdown      #
#                                                          #
# This will cause the main thread to be killed along with  #
#   all the threads it created. This might result in some  #
#   undesired behavior                                     #
# https://stackoverflow.com/questions/9095316/handling-    #
#   exceptions-raised-in-a-ruby-thread#                    #
#                                                          #
# This setting is false by default. raising error here if  #
#   it is set by explicitly by a dependency                #
############################################################

raise ThreadError::AbortOnExceptionSet, 'abort_on_exception set to true for Thread class' if Thread.abort_on_exception
