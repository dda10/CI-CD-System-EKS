class Constant {
  static String DEFAULT_SINGLE_BRANCH = "main"
  static String DEFAULT_MULTIPLE_BRANCH = "((main)|(develop)|(release/.*))"
  static String DEFAULT_SCRIPT_PATH = "Jenkinsfile"
  static String SCM_DOMAIN = "http://k8s-gitlab-gitlabwe-11c16d8044-709872649.ap-southeast-1.elb.amazonaws.com"
  static String MANIFEST_DIRECTORY = "jenkins-config/job-dsl/manifests"
}
